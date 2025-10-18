#!/usr/bin/luajit

local setmetatable   = setmetatable
local table          = table
local os             = os
local io             = io
local posix          = require "posix"
local bit            = require "bit"
local ffi            = require "ffi"
local C              = ffi.C

local sizeof         = ffi.sizeof
local uint32_array_t = ffi.typeof("uint32_t[?]")
local uint64_array_t = ffi.typeof("uint64_t[?]")
local int_array_t    = ffi.typeof("int[?]")
local char_array_t   = ffi.typeof("char[?]")


local R_OK      = 4
local W_OK      = 2
local X_OK      = 1
local F_OK      = 0

local FD_STDOUT = 1
local FD_STDERR = 2

local LOCK_SH   = 1 --Place a shared lock.
local LOCK_EX   = 2 --Place an exclusive lock.
local LOCK_NB   = 4 --To make a nonblocking request
local LOCK_UN   = 8 --Remove an existing lock held by this process



local const

local _M  = {}
_M._VERSION = '1.0'
local mt  = { __metatable = {}, __index = _M  }

ffi.cdef [[
    typedef int32_t pid_t;
    typedef long size_t;
    typedef long ssize_t;
    typedef uint32_t in_addr_t;
    typedef uint32_t socklen_t;

    enum {
        UNIX_PATH_MAX   = 108,
        UNIX_SOCK_SIZE  = 110,
        SOCK_SIZE       = 16,
        IF_NAMESIZE     = 16,
    };

    enum {
        AES_MAXNR = 14,
        AES_BLOCK_SIZE = 16,
    };
    typedef struct {
        unsigned int rd_key[4 * (AES_MAXNR + 1)];
        int rounds;
    }AES_KEY;

    union chksum {
        uint32_t n;
        struct { uint16_t sn1; uint16_t sn2; };
    };
    struct in_addr {
        in_addr_t s_addr;
    };

    union sock_len {
        unsigned int   lenptr[1];
        unsigned int   length;
    };
    struct timeval  { long tv_sec; long tv_usec; };
    struct timezone { int tz_minuteswest; int tz_dsttime; };
    struct timespec {
            long tv_sec;
            union {
                    long tv_usec;
                    long tv_nsec;
            };
    };
    struct itimerspec { struct timespec it_interval; struct timespec it_value; };

    struct sockaddr {
            unsigned short family;
            char sa_data[14];
    };

    struct sockaddr_in {
            unsigned short family;
            unsigned short sin_port;
            struct in_addr sin_addr;
            union {
                    unsigned int   lenptr[1];
                    unsigned int   length;
            };
            /* Pad to size of (struct sockaddr) */
            unsigned char __pad[SOCK_SIZE - 2-2-4-4];
    };

    uint32_t htonl(uint32_t hostlong);
    uint16_t htons(uint16_t hostshort);
    uint32_t ntohl(uint32_t netlong);
    uint16_t ntohs(uint16_t netshort);
    in_addr_t inet_addr(const char *cp);
    ssize_t sendto(int sockfd, const void *buf, size_t len, int flags,
                    void *dest_addr, socklen_t addrlen);
    int close(int fd);
    int socket(int domain, int type, int protocol);
    pid_t fork(void);

    int pipe(int pipefd[2]);
    unsigned int sleep(unsigned int seconds);
    pid_t waitpid(pid_t pid, int *status, int options);

    int close(int fd);
    int dup2(int oldfd, int newfd);
    int execlp(const char *file, const char *arg, ...);
    int printf(const char *format, ...);
    unsigned long long int strtoull(const char *nptr, char **endptr, int base);
    unsigned long int strtoul( const char * ptr,char ** endptr,int base );

    ssize_t read(int fd, void *buf, size_t count);
    char *strerror(int errnum);

    typedef struct {
        unsigned long i[2];
        unsigned long buf[4];
        unsigned char in[64];
        unsigned char digest[16];
    } MD5_CTX;
    unsigned char *MD5(const unsigned char *d, size_t n, unsigned char *md);
    int MD5_Init(MD5_CTX *c);
    int MD5_Update(MD5_CTX *c, const void *data, unsigned long len);
    int MD5_Final(unsigned char *md, MD5_CTX *c);

    int access(const char *pathname, int mode);
    int clock_gettime(int, struct timespec *tp);

    int open(const char *pathname, int flags, ...);
    int flock(int fd, int operation);

    typedef void (*sighandler_t) (int);
    sighandler_t signal(int sig, sighandler_t handler);
    int kill(int32_t pid, int sig);
    pid_t getpid(void);
    pid_t getppid(void);
    int utimes(const char *filename, const struct timeval times[2]);
    int chdir(const char *path);
    int daemon(int nochdir, int noclose);

    int AES_set_encrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key);
    int AES_set_decrypt_key(const unsigned char *userKey, const int bits, AES_KEY *key);

    void AES_cbc_encrypt(const unsigned char *in, unsigned char *out, size_t length,
                        const AES_KEY *key,const unsigned char *ivec, const int enc);

    void *memset(void *s, int c, size_t n);
    void *memcpy(void *dest, const void *src, size_t n);
    size_t strlen(const char *s);
    ssize_t readlink(const char *path, char *buf, size_t bufsiz);
]]




function ffi.geterr()
    return ffi.string(C.strerror(ffi.errno()))
end

local function posix_init()
    if posix.version == "Luaposix for iKuai" then
        const = require "const"
    else
        const = posix
    end
end



local function __get_fmodified_on_2x(file)
    local h = io.popen(string.format("stat %s | awk '{print $1}' ",file))
    local last_modified
    if h then
        last_modified = h:read()
        h:close()
    end
    return tonumber(last_modified)
end

local function __get_fmodified(file)
    local h = io.popen("stat -c %Y " .. file)
    local last_modified
    if h then
        last_modified = h:read()
        h:close()
    end
    return tonumber(last_modified)
end


function  _M.new(self,log_file,log_size)
    posix_init()

    local libssl
    --- there is no /usr/lib/libssl.so soft link in 2.7.x
    local ssl_path = "/usr/lib/libssl.so.1.0.0"
    if C.access(ssl_path,F_OK) ~= 0  then
        if  C.access("/etc/release",F_OK) == 0  then
            ssl_path = "libssl"
        elseif C.access("/usr/lib/libssl.so",F_OK) == 0  then
            ssl_path = "/usr/lib/libssl.so"
        else
            ssl_path = nil
        end
    end
    if ssl_path then
        libssl = ffi.load(ssl_path)
    end

    local get_fmd_func = __get_fmodified
    if not get_fmd_func("/etc") then
        get_fmd_func = __get_fmodified_on_2x
    end

    if log_file then
        os.execute(string.format("mkdir -p $(dirname %s)",log_file))
    end

    return  setmetatable(
        {  _libssl        = libssl,
            _get_fmd_func = get_fmd_func,
            _log_file     = log_file,
            _log_size     = log_size or 20480
        },  mt)
end


function _M.exist_file(self,file)
    return (C.access(file,F_OK) == 0)
end

function _M.wexitstatus(self,status)
    return bit.rshift(status, 8)
end


--res, data = iksystem("ls -lh")
function _M.system(self,cmd)
    if not cmd or cmd == "" then
        return false, "cmd cannot empty"
    end

    local data=""
    local pipefd = int_array_t(2)
    local buff = char_array_t(1024)

    local res = C.pipe(pipefd)
    if res < 0 then
        return false, ffi.geterr()
    end

    local rfd = pipefd[0]
    local wfd = pipefd[1]

    local pid = C.fork()
    if pid == 0 then
        C.dup2(wfd, FD_STDOUT)
        C.close(wfd)
        C.close(rfd)

        C.execlp("bash","bash","-c",cmd,nil)
        os.exit(1)
    elseif pid > 0 then
        C.close(wfd)
        local err
        while 1 do
            local len = C.read(rfd, buff, sizeof(buff))
            if len == 0 then
                break
            elseif len < 0 then
                err = ffi.geterr()
                break
            end
            data = data .. ffi.string(buff, len)
            --C.printf("%s",ffi.string(buff, len))
        end

        local child_exit_sta = int_array_t(1)
        C.waitpid(pid, child_exit_sta, 0)
        C.close(rfd)
        if err then
            return false, err
        else
            return self:wexitstatus(child_exit_sta[0]) == 0, data
        end
    else
        return false, ffi.geterr()
    end

end

function _M.md5(self,str, len)
    if not self._libssl then
        return ""
    end

    local __len
    if len then
        __len = len
    else
        __len = #str
    end

    local md5str = ffi.new("unsigned char[?]", 17)
    self._libssl.MD5(str, __len, md5str)

    return string.format(
        "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        md5str[0],md5str[1],md5str[2],md5str[3],md5str[4],md5str[5],md5str[6],md5str[7],
        md5str[8],md5str[9],md5str[10],md5str[11],md5str[12],md5str[13],md5str[14],md5str[15])
end

function _M.fmd5(self,file)
    if not self._libssl then
        return ""
    end

    local md5str = ffi.new("unsigned char[?]", 17)
    local md5_ctx = ffi.new('MD5_CTX[1]')

    local f = io.open(file)
    if not f then return nil end

    self._libssl.MD5_Init(md5_ctx[0])
    while true do
        local buf = f:read(65536)
        if not buf then break end
        self._libssl.MD5_Update(md5_ctx[0], buf, #buf)
    end

    self._libssl.MD5_Final(md5str, md5_ctx[0]);
    f:close()

    return string.format(
        "%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        md5str[0],md5str[1],md5str[2],md5str[3],md5str[4],md5str[5],md5str[6],md5str[7],
        md5str[8],md5str[9],md5str[10],md5str[11],md5str[12],md5str[13],md5str[14],md5str[15])
end



function _M.strsum(self,str)
    if not str then return 0 end
    local Sum = ffi.new("unsigned int[?]",1)
    for i=1,#str do
        Sum[0] = Sum[0] + str:byte(i)
    end

    return Sum[0]
end

function _M.strtoul(self,str, int)
    local _str = str or "0"
    local _int = int or 10
    return ffi.C.strtoul(_str,nil,_int)
end

function _M.strtoull(self,str, int)
    local _str = str or "0"
    local _int = int or 10
    return ffi.C.strtoull(_str,nil,_int)
end

function _M.uint32(self)
    return ffi.new("uint32_t[1]")[0]
end

function _M.uint64(self)
    return ffi.new("uint64_t[1]")[0]
end

------------------------------------------
-- mode :
--      w : write and clean previous beytes
--      a : write and append
--      b : binary mode , with other mode
function _M.writefile(self,data, file, mode)
    local f = io.open(file, mode or "w")
    if f then
        f:write(data)
        f:close()
        return true
    end
    return false
end


function _M.readfile_line(self,file, line_n)
    local f = io.open(file)
    local data
    if f then
        if line_n == 1 then
            data = f:read("*l")
        else
            local n = 0
            for line in f:lines() do
                n = n + 1
                if n == line_n then
                    data = line
                    break
                end
            end
        end
        f:close()
    end

    return data
end

function _M.dir_is_writable(self,dir_name)
    if not posix.lstat(dir_name) then
        return false
    end
    local test_file = dir_name .. "/.test"
    local tmp_str = os.date("%y-%m-%d %H:%M:%S")
    if not self:writefile(tmp_str,test_file) then
        os.remove(test_file)
        return false
    end
    local str = self:readfile_line(test_file,1)
    os.remove(test_file)
    return str and str == tmp_str
end


function _M.readfile(self,file)
    local f = io.open(file)
    local data
    if f then
        data = f:read("*a")
        f:close()
    end

    return data
end

function _M.fsize(self,file)
    local f = io.open(file)
    local s = -1
    if f then
        s = f:seek("end")
        f:close()
    end
    return s
end

function _M.get_fmodified(self,file)
    return self._get_fmd_func(file)
end

function _M.parsearg(self,arg)
    local arg_t = {}
    for i, val in pairs(arg) do
        if val:match("=") then
            local k,v = val:match("^([^=]+)=(.*)")
            if k then
                arg_t[k] = v
            end
        else
            arg_t[val] = true
        end
    end

    return arg_t
end


function _M.run_back(self,Func, ...)
    local pid = C.fork()
    if pid == 0 then
        C.daemon(1, 0)
        Func(...)
        os.exit(0)
    elseif pid > 0 then
        C.waitpid(pid, nil, 0)
        return true
    else
        return false
    end
end

function _M.split(self,str, delimiter)
    if str==nil or str=='' or delimiter==nil then
        return nil
    end
    local result = {}

    local __find = str:match(delimiter)

    if not __find then
        table.insert(result, str)
    else
        local s = str .. __find
        for r in s:gmatch("(.-)"..delimiter) do
            table.insert(result, r)
        end
    end
    return result
end

function _M.cp(self,src, dst)
    return self:system("cp -rf "..src.." "..dst)
end

function _M.mkdir(self,...)
    local dirs = ""
    local arg_t = {...}
    for i=1,10000 do
        if not arg_t[i] then
            break
        end
        dirs = dirs .. " " ..arg_t[i]
    end
    return self:system("mkdir -p "..dirs)
end

function _M.touch(self,...)
    local open = io.open
    local arg_t = {...}
    for i=1,10000 do
        if not arg_t[i] then
            break
        end
        open(arg_t[i], "a"):close()
    end
end


function _M.lock(self,file, operation)
    --0x01B6 == 0666
    local fd = C.open(file, const.O_RDONLY + const.O_NONBLOCK + const.O_CREAT, 0x01B6)
    if not fd then return false end

    if C.flock(fd, operation or LOCK_EX) == 0 then
        return fd
    else
        return -1
    end
end

function _M.unlock(self,fd)
    local ret = ( C.flock(fd, LOCK_UN) == 0 )
    C.close(fd)
    return ret
end

function _M.sleep(self,s)
    C.sleep(s)
end

function _M.kill(self,pid,sig)
    C.kill(pid,sig)
end

function _M.getpid(self)
    return C.getpid()
end


function _M.signal(self,s,handler)
    return C.signal(s, handler)
end


function _M.log(self,...)
    local log_file = self._log_file
    if not log_file then return end

    local size = self:fsize(log_file)
    if size > self._log_size then
        os.execute(string.format("mv -f %s %s.bak",log_file,log_file))
    end
    self:writefile(string.format('[%s] %s\n',os.date("%y-%m-%d %H:%M:%S"),string.format(...)),log_file,"a")
end

function _M.set_log_file(self,file_name)
    if file_name then
        os.execute(string.format("mkdir -p $(dirname %s)",file_name))
    end
    self._log_file = file_name
end

function _M.set_log_size(self,log_size)
    self._log_size = log_size
end

return  _M

