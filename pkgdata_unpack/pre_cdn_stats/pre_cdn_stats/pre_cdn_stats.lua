#!/usr/bin/luajit
local cjson		  = require "cjson.safe"
local posix		  = require "posix"
local ffi		  = require "ffi"
local C	  = ffi.C

local sizeof = ffi.sizeof
local int_array_t = ffi.typeof("int[?]")
local char_array_t = ffi.typeof("char[?]")
local nat_type_path = "/etc/log/.pre_cdn_nat/"

local FD_STDOUT = 1
local FD_STDERR = 2

local R_OK = 4
local W_OK = 2
local X_OK = 1
local F_OK = 0

ffi.cdef [[
	typedef int32_t pid_t;
	typedef long size_t;
	typedef long ssize_t;

	int close(int fd);
	pid_t fork(void);

	int pipe(int pipefd[2]);
	unsigned int sleep(unsigned int seconds);
	pid_t waitpid(pid_t pid, int *status, int options);

	int close(int fd);
	int dup2(int oldfd, int newfd);
	int execlp(const char *file, const char *arg, ...);

	ssize_t read(int fd, void *buf, size_t count);

	int access(const char *pathname, int mode);
]]

function ik_wexitstatus(status)
	return bit.rshift(status, 8)
end

--执行系统命令,并获取返回内容和状态
--res, data = iksystem("ls -lh")
function ik_system(cmd)
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
			return ik_wexitstatus(child_exit_sta[0]) == 0, data
		end
	else
		return false, ffi.geterr()
	end

end

function ik_exist_file(file)
	return (C.access(file,F_OK) == 0)
end

function ik_readfile(file)
	local f = io.open(file)
	local data
	if f then
		data = f:read("*a")
		f:close()
	end

	return data
end

function ik_readfile_line(file, line_n)
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

--获取内存使用率
--function get_memrate()
function get_mem_info()
	local f = io.open("/proc/meminfo")
	local t = {}
	if f then
		for line in f:lines() do
			local key,val = string.match(line,"^([^ ]+) *: *([0-9]*)")
			if key then
				t[key] = val
			end
		end
		f:close()
	end
	if t["MemAvailable"] == nil then
		t["MemAvailable"] = t["MemFree"] + t["Buffers"] + t["Cached"] + t["Shmem"]
	end
	return math.floor((t["MemTotal"] - t["MemAvailable"]) * 100 / t["MemTotal"]),t["MemTotal"],t["MemAvailable"]
end

--获取cpu使用率
function get_cpurate()
	local f = io.open("/tmp/iktmp/monitor-ikstat/cpu")
	if f then
		for line in f:lines() do
			if string.match(line, "cpu ") ~= nil then
				local _, p = string.find(line, " ")
				local cpurate = string.sub(line, p + 1)
				local len = string.len(cpurate)
				cpurate = string.sub(cpurate, 1, len - 1)
				return cpurate
			end
		end
		f:close()
	end
	return nil
end

--获取cpu合数
function get_cpu_info()
	local err, nr_cpus = ik_system("grep -c 'processor' /proc/cpuinfo")
	if err ~= true then
		nr_cpus = 0
	end
	nr_cpus = string.match(nr_cpus, "([^ ]+)\n")

	local err, cpu_model = ik_system("( grep '^model name' /proc/cpuinfo || grep '^cpu model' /proc/cpuinfo ) | awk -F': ' '{printf(\"%s\",$2); exit 0;}'")
	if err ~= true then
		cpu_model="--"
	end

	local err, cpu_mhz = ik_system("cat /proc/cpuinfo|grep \"cpu MHz\"|head -n 1|awk -F ':' '{printf \"%.f\",$2}'")
	if err ~= true then
		cpu_mhz="--"
	end
	local f = io.open("/sys/devices/system/cpu/cpufreq/policy0/cpuinfo_max_freq")
	if f then
		for line in f:lines() do
			cpu_mhz=line/1000
		end
		f:close()
	end

	return nr_cpus or 0,cpu_model or "--",cpu_mhz or "--"
end

function get_max_disk_info()
	--df -m
	local err, data = ik_system("df -m")
	if err ~= true then
		return "--",0,0
	end
	local max_block = 0
	local t = {}
	for w in string.gmatch(data, "([^%c]+)\n") do
		local fs,blocks,used,avail,use,mount = string.match(w, "/dev/([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+)")
		if fs and mount ~= "/etc/mnt" and mount ~= "/" then
			blocks = tonumber(blocks)
			if blocks > max_block then
				t["fs"] = fs
				t["blocks"] = blocks
				t["used"] = used
				t["avail"] = avail
				t["mount"] = mount
				max_block = blocks
			end
		end
	end
	return t["fs"] or "--",t["blocks"] or 0,t["avail"] or 0
end
function get_disk_info()
	--df -m
	local err, data = ik_system("df -m")
	if err ~= true then
		return "[]"
	end
	local arry = {}
	for w in string.gmatch(data, "([^%c]+)\n") do
		local t = {}
		local fs,blocks,used,avail,use,mount = string.match(w, "/dev/([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+) +([^ ]+)")
		if fs and mount ~= "/etc/mnt" and mount ~= "/" then
			t["fs"] = fs
			t["total_MB"] = blocks
			t["used_MB"] = used
			t["avail_MB"] = avail
			t["mount"] = mount
			table.insert(arry, t)
		end
	end

	if #arry == 0 then
		return "[]"
	else
		return string.gsub(string.format("%s", cjson.encode(arry)), "{}", "[]")
	end
end

-- 获取运行时间
function get_runtime()
	local data = ik_readfile("/proc/uptime")
	local runtime = nil
	if data then
		local p, _ = string.find(data, " ")
		runtime = string.sub(data, 1, p - 1)
	end
	if runtime then
		return runtime
	else
		return 0
	end
end

--获取/etc/release里面的数据
function load_ikrelease()
	local f = io.open("/etc/release")
	local t = {}
	if f then
		for line in f:lines() do
			local key,val = string.match(line,"^([^ ]+) *= *(.+)")
			if key then
				t[key] = val
			end
		end
		f:close()
	end

	t.VERSION_NUM = tonumber(t.VERSION_NUM)
	return t
end

local function ikL_split(str, delimiter)
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

local function get_cdn_info()
	local rel_info = load_ikrelease()
	-- system_version
	local system_version = rel_info["VERSTRING"]
	-- gwid
	local gwid = rel_info["GWID"]
	-- cpurate
	local cpurate = get_cpurate()
	-- memrate
	local memrate, mem_total_kB, mem_avail_kB = get_mem_info()
	-- runtime
	local runtime = get_runtime()
	-- firmware
	local firmware = rel_info["FIRMWARENAME"]
	-- timestamp
	local timestamp = os.time()
	-- wans
	local wans = get_all_wans()
	--print(wans)
	local nr_cpus,cpu_model,cpu_mhz = get_cpu_info()
	--print(nr_cpus,cpu_model,cpu_mhz)

	local disk_info = get_disk_info()
	local cdn_info = string.format("{\"gwid\":\"%s\",\"system_version\":%s,\"runtime\":%d,\"timestamp\":%d,\"cpurate\":\"%s\",\"nr_cpus\":\"%s\",\"cpu_model\":\"%s\",\"cpu_mhz\":\"%s\",\"memrate\":\"%s\",\"mem_total_kB\":\"%s\",\"mem_avail_kB\":\"%s\",\"wans\":%s,\"disks\":%s}",
					gwid, system_version, runtime, timestamp, cpurate, nr_cpus, cpu_model, cpu_mhz, memrate, mem_total_kB, mem_avail_kB, wans, disk_info)
	return cdn_info
end

function get_ip_nat_by_iface(iface)
	local date_name = os.date("%Y%m%d")
	local path=nat_type_path.."/"..date_name.."_nat/"..iface
	local public_ip, nat_type

	--public_ip=112.87.1.12 nat_type=nat0
	local f = io.open(path)
	if f then
		for line in f:lines() do
			public_ip, nat_type = string.match(line, "public_ip=([^ ]+) nat_type=([^ ]+)") 
		end
		f:close()
	end
	if public_ip then
		return public_ip,nat_type or "unknown"
	end

	cmd = string.format("ifconfig %s|grep \"inet addr\"",iface)
	err, data = ik_system(cmd)
	if err ~= true then
		return "--"
	end
	local local_ip = string.match(data, "inet addr:([^ ]+) ")

	return local_ip or "--","unknown"
end

function get_speedtest_by_iface(iface)
	local upspped = 0
	local downspeed = 0

	local cmd = string.format("cat /etc/log/speedtest/%s |grep -E \"up avg|down avg\" 2>/dev/null",iface)
	local err, data = ik_system(cmd)
	if err ~= true then
		return 0,0
	end
	local t = {}
	for w in string.gmatch(data, "([^%c]+)\n") do
		local type,avg = string.match(w, "([^%s]+) avg = ([^%s]+) KB/s") do
			t[type]=avg
		end
	end
	return t["up"] or 0,t["down"] or 0
end

function get_all_wans()
	os.execute("/tmp/ikpkg/pre_cdn_stats/nat_type.sh 2>/dev/null")
	local err, data = ik_system("route -n | awk -va=0.0.0.0 '$1==a&&$3==a&&!s[$NF]&&$NF!~/^pptp|^l2tp|ovpn|^ppp/ {s[$NF]=1;print $NF}'")
	if err ~= true then
		return "[]"
	end
	local arry = {}
	for iface in string.gmatch(data, "([^%c]+)\n") do
		t = {}
		t["iface"]=iface
		t["ip"],t["nat_type"]=get_ip_nat_by_iface(iface)
		upload,download = get_speedtest_by_iface(iface)
		t["up_KB"]=upload
		t["down_KB"]=download
		--arry["status"]=0
		table.insert(arry, t)
	end

	if #arry == 0 then
		return "[]"
	else
		return string.gsub(string.format("%s", cjson.encode(arry)), "{}", "[]")
	end
end


function main()
	local cmd_type = nil
	if arg[1] == nil  then
		cmd_type = "cdn_info"
	else
		cmd_type = arg[1]
	end

	if cmd_type == "cdn_info" then
		cdn_info = get_cdn_info()
		if cdn_info ~= nil then
			print(cdn_info)
		end
	end

end

main()


