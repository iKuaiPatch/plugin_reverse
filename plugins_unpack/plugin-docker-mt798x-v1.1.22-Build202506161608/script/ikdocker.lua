#!/usr/bin/luajit
local DEBUG = false
local DOCKER_PULL_STATUS = "/var/run/docker.pull.status"
local DOCKER_PULL_LOCK = "/var/run/docker.pull.lock"
local DOCKER_UNIX_PATH = "/var/run/docker.sock"
local DOCKER_MEM_PATH  = "/sys/fs/cgroup/memory/docker"
local DOCKER_CPU_PATH  = "/sys/fs/cgroup/cpuacct/docker"
local DOCKER_CPU_USED_PATH = "/tmp/iktmp/monitor-ikstat/dkcpu"

local ffi = require "ffi"
local cjson = require "cjson"
local flock = require "iklua.ffi.flock"
local str_match = string.match
local str_format = string.format
local DISK_USER = "/etc/disk_user"
local C = ffi.C


ffi.cdef [[
	struct curl_slist {
	  char *data;
	  struct curl_slist *next;
	};

    int curl_version();
    void *curl_easy_init();
    int curl_easy_setopt(void *curl, int option, ...);
	int curl_easy_getinfo(void *curl, int option, ...);
    int curl_easy_perform(void *curl);
    void curl_easy_cleanup(void *curl);
	struct curl_slist *curl_slist_append(struct curl_slist *list, const char *data);

	int access(const char *pathname, int mode);
	unsigned int sleep(unsigned int seconds);
	char *dirname(char *path);
]]

local libcurl = ffi.load("libcurl.so.4")
local int32 = ffi.new("int[1]")
local uint64 = ffi.new("uint64_t[1]")

CURLINFO_STRING   = 0x100000
CURLINFO_LONG     = 0x200000
CURLINFO_DOUBLE   = 0x300000
CURLINFO_SLIST    = 0x400000
CURLINFO_PTR      = 0x400000
CURLINFO_SOCKET   = 0x500000
CURLINFO_OFF_T    = 0x600000
CURLINFO_MASK     = 0x0fffff
CURLINFO_TYPEMASK = 0xf00000

CURLINFO_RESPONSE_CODE    = CURLINFO_LONG   + 2

CURLOPTTYPE_LONG          = 0
CURLOPTTYPE_OBJECTPOINT   = 10000
CURLOPTTYPE_FUNCTIONPOINT = 20000
CURLOPTTYPE_OFF_T         = 30000

CURLOPT_VERBOSE          = CURLOPTTYPE_LONG + 41
CURLOPT_POST             = CURLOPTTYPE_LONG + 47
CURLOPT_FOLLOWLOCATION   = CURLOPTTYPE_LONG + 52
CURLOPT_URL              = CURLOPTTYPE_OBJECTPOINT + 2
CURLOPT_POSTFIELDS       = CURLOPTTYPE_OBJECTPOINT + 15
CURLOPT_HTTPHEADER       = CURLOPTTYPE_OBJECTPOINT + 23
CURLOPT_CUSTOMREQUEST    = CURLOPTTYPE_OBJECTPOINT + 36
CURLOPT_UNIX_SOCKET_PATH = CURLOPTTYPE_OBJECTPOINT + 231
CURLOPT_WRITEFUNCTION    = CURLOPTTYPE_FUNCTIONPOINT + 11
CURLOPT_HEADERFUNCTION   = CURLOPTTYPE_FUNCTIONPOINT + 79
CURLOPT_INFILESIZE_LARGE = CURLOPTTYPE_OFF_T + 115


function url_decode(str)
	local ptr = ffi.cast("unsigned char *", str)
	local store = ffi.new("unsigned char[?]", #str)
	local n = #str
	local i = 0
	local N = 0
	while n > i do
		local c = 0
		if ptr[i] == 37 then
			local c1 = ptr[i+1];
			local c2 = ptr[i+2];
			if c1 >= 48 and c1 <= 57 then
				c = (c1 - 48) * 16
			else
				c = (c1 - ((c1>70) and 97 or 65) +10) * 16
			end
			if c2 >= 48 and c2 <= 57 then
				c = c + c2 - 48
			else
				c = c + c2 - ((c2>70) and 97 or 65) + 10
			end
			i = i + 2
		else
			c = ptr[i]
		end

		store[N] = c
		N = N + 1
		i = i + 1
	end

	return ffi.string(store, N)
end

function url_encode(str)
	local ffi_copy = ffi.copy
	local ptr = ffi.cast("unsigned char *", str)
	local store = ffi.new("unsigned char[?]", #str*3)
	local N = 0
	for i=0,#str-1 do
		if ptr[i] == 44 or ptr[i] == 58 or ptr[i] == 95 or
		(ptr[i] >= 48 and ptr[i] <= 57) or
		(ptr[i] >= 65 and ptr[i] <= 90) or
		(ptr[i] >= 97 and ptr[i] <= 122) then
			store[N] = ptr[i]
			N = N + 1
		else
			ffi_copy(store+N, str_format("%%%02X", ptr[i]), 3)
			N = N + 3
		end
	end

	return ffi.string(store, N)
end

function write_head_cb(ptr, size, nmemb, stream)
	local bytes = size * nmemb
	HEAD_BUFFER = HEAD_BUFFER .. ffi.string(ptr, bytes)
	return bytes
end

function write_data_cb(ptr, size, nmemb, stream)
	local bytes = size * nmemb
	DATA_BUFFER = DATA_BUFFER .. ffi.string(ptr, bytes)
	return bytes
end

local write_head_ptr = ffi.cast("size_t (*)(char *, size_t, size_t, void *)", write_head_cb)
local write_data_ptr = ffi.cast("size_t (*)(char *, size_t, size_t, void *)", write_data_cb)


function curl_easy_setopt(_curl, operate, option)
	
	if type(option) == "number" then
		uint64[0] = option
		return libcurl.curl_easy_setopt(_curl, operate, uint64[0])
	else
		return libcurl.curl_easy_setopt(_curl, operate, option)
	end
end

function curl_request(param)
	HEAD_BUFFER = ""
	DATA_BUFFER = ""
	local ret, err
	local post_fp
	local headers
	local http_url = param.uri
	local method = param.method
	local curl = libcurl.curl_easy_init()
	ikL_assert(curl, "internal error -1")

	if param.args then
		local n = 0
		local _args = ""
		for k,v in pairs(param.args) do
			n = n + 1
			_args = str_format("%s%s%s=%s", _args, (n == 1) and "?" or "&", k, v)
		end
		http_url = http_url .. _args
	end

	if DEBUG then
		curl_easy_setopt(curl, CURLOPT_VERBOSE, 1)
		print("> URL: ".. http_url)
		print()
	end

	curl_easy_setopt(curl, CURLOPT_UNIX_SOCKET_PATH, DOCKER_UNIX_PATH)
	curl_easy_setopt(curl, CURLOPT_URL, http_url)
	curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, write_head_ptr)
	curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, param.writefunc or write_data_ptr)
	curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1);
	if method == "POST" then
		curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method)
		curl_easy_setopt(curl, CURLOPT_POST, 1);
		if param.postdata then
			curl_easy_setopt(curl, CURLOPT_POSTFIELDS, param.postdata)
			if DEBUG then	
				print("> POSTDATA:")
				print(post_data)
				print()
			end
		else
			curl_easy_setopt(curl, CURLOPT_POSTFIELDS, "")
			curl_easy_setopt(curl, CURLOPT_INFILESIZE_LARGE, 0)
		end
	elseif method and method ~= "GET" then
		curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, method);
	end

	if param.heads then
		for k,v in pairs(param.heads) do
			headers = libcurl.curl_slist_append(headers, k .. ": " .. v)
		end
		if headers then
			curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers)
		end
	end

	local res = libcurl.curl_easy_perform(curl)
	if res == 0 then
		res = libcurl.curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, int32);
	end

	if res == 7 then
		print("Docker service not running")
		os.exit(1)
	elseif res > 0 then
		print("Connect docker service failed, err = " .. res)
		os.exit(1)
	end

	libcurl.curl_easy_cleanup(curl)
	return int32[0], HEAD_BUFFER, DATA_BUFFER
end

--Inspect an network
function network_inspect(param, is_edit)
	local curl_req_param = {
		uri = ikL_format_url('/networks/%s?filters={"type":{"custom":true}}', param.id ),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)
	local json = verify_is_json(data)

	if is_edit then
		return json
	else
		print(cjson.encode(json))
		return true
	end
end

function network_get_name(param)
	local curl_req_param = {
		uri = ikL_format_url('/networks/%s?filters={"type":{"custom":true}}', param.id or ""),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)
	local xjson = {}
	if json.Name then
		json = {json}
	end
	for _,t in ipairs(json) do
		table.insert(xjson, t.Name)
	end
	if #xjson > 0 then
		print(cjson.encode(xjson))
	else
		print('[]')
	end
	return true
end

function network_get_list(param)
	local curl_req_param = {
		uri = ikL_format_url('/networks/%s?filters={"type":{"custom":true}}', param.name or ""),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)
	local xjson = {}
	if json.Name then
		json = {json}
	end
	for _,t in ipairs(json) do
		local subnet, gateway, subnet6, gateway6
		if t.IPAM.Config[1] then
			subnet = t.IPAM.Config[1].Subnet 
			gateway = t.IPAM.Config[1].Gateway
		end
		if t.IPAM.Config[2] then
			subnet6 = t.IPAM.Config[2].Subnet 
			gateway6 = t.IPAM.Config[2].Gateway
		end
		print(string.format("id=%s name=%s subnet=%s gateway=%s subnet6=%s gateway6=%s comment=%s", t.Id,t.Name,subnet or "",gateway or "",subnet6 or "",gateway6 or "",t.Labels.comment or ""))

	end

	return true
end

function network_get(param)
	local curl_req_param = {
		uri = ikL_format_url('/networks/%s?filters={"type":{"custom":true}}', param.id or ""),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)
	local xjson = {}
	if json.Name then
		json = {json}
	end
	for _,t in ipairs(json) do
		local subnet, gateway, subnet6, gateway6
		if t.IPAM.Config[1] then
			subnet = t.IPAM.Config[1].Subnet 
			gateway = t.IPAM.Config[1].Gateway
		end
		if t.IPAM.Config[2] then
			subnet6 = t.IPAM.Config[2].Subnet 
			gateway6 = t.IPAM.Config[2].Gateway
		end
		local _t = {
			id = t.Id,
			name = t.Name,
			subnet = subnet or "",
			gateway = gateway or "",
			subnet6 = subnet6 or "",
			gateway6 = gateway6 or "",
			comment = t.Labels.comment or "",
		}

		table.insert(xjson, _t)
	end

	if #xjson > 0 then
		print(cjson.encode(xjson))
	else
		print('[]')
	end
	return true
end

function network_edit(param)
	local inspect_param = { id = param.id}
	local inspect = network_inspect(inspect_param, true)

	local disconnect_param = {}
	for cid,v in pairs(inspect.Containers) do
		disconnect_param.id = inspect.Id
		disconnect_param.cid = cid
		network_disconnect(disconnect_param)
	end

	local del_param = { id = param.id}
	network_del(del_param)
	local add_json = network_add(param, true)

	local connect_param = {}
	for cid,v in pairs(inspect.Containers) do
		connect_param.id = add_json.Id
		connect_param.cid = cid
		connect_param.ipaddr = string.gsub(v.IPv4Address, "/%d+", "") or ""
		network_connect(connect_param)
	end

	print(add_json.Id)
end

function network_add(param, is_edit)
	local EnableIPv6 = (param.subnet6 and param.subnet6 ~= "")
	local ipv6config = EnableIPv6 and {Subnet = param.subnet6 , Gateway = param.gateway6 }
	local post_t = {
		Name = param.name,
		EnableIPv6 = EnableIPv6,
		Internal = true,
		Attachable = false,
		Ingress = false,
		IPAM = {
			Driver = "default",
			Config = {	
				{Subnet = param.subnet, Gateway = param.gateway },
				ipv6config
			}
		},
		Options = {
			["com.docker.network.bridge.name"] = param.name,
		},
		Labels = { comment = param.comment },
	}

	local curl_req_param = {
		uri = ikL_format_url("/networks/create"),
		method = "POST",
		heads = {
			["Content-Type"] = "application/json",
		},
		postdata = cjson.encode(post_t),
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 201, data)

	local json = verify_is_json(data)
	if is_edit then
		return json
	else
		print(json.Id)
	end
end

function network_del(param)
	for _id in param.id:gmatch("[^,]+") do
		local curl_req_param = {
			uri = ikL_format_url('/networks/%s', _id),
			method = "DELETE",
		}
		local status, head, data = curl_request(curl_req_param)
		ikL_assert_response(status == 204, data)
	end
end

--param: id= cid= ipaddr= ip6addr=
function __network_connect(param)
	local post_t = {
		Container = param.cid,
		EndpointConfig = {
			IPAMConfig = {
			IPv4Address = param.ipaddr,
			IPv6Address = param.ip6addr
			}
		}
	}

	local curl_req_param = {
		uri = ikL_format_url('/networks/%s/connect', param.id),
		method = "POST",
		heads = {
			["Content-Type"] = "application/json",
		},
		postdata = cjson.encode(post_t),
	}

	return curl_request(curl_req_param)
end

function network_connect(param, old)
	local status, head, data = __network_connect(param)
	ikL_assert_response(status == 200, data)
end

--param: id= cid=
function __network_disconnect(param)
	local post_t = {
		Container = param.cid,
		Force = true,
	}

	local curl_req_param = {
		uri = ikL_format_url('/networks/%s/disconnect', param.id),
		method = "POST",
		heads = {
			["Content-Type"] = "application/json",
		},
		postdata = cjson.encode(post_t),
	}

	return curl_request(curl_req_param)
end
function network_disconnect(param)
	local status, head, data = __network_disconnect(param)
	ikL_assert_response(status == 200, data)
end

--Inspect an image
function images_get_info(param)
	local curl_req_param = {
		uri = ikL_format_url('/images/%s/json?all=1', param.id),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)
	json.GraphDriver = nil
	json.RootFS = nil
	print(cjson.encode(json))
	return true
end
--list images for name
function images_get_name(param)
	local curl_req_param = {
		uri = ikL_format_url('/images/json?all=1'),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)
	local xjson = {}
	for _,t in ipairs(json) do
		if type(t.RepoTags) == "table" and t.RepoTags[1] then
			table.insert(xjson, t.RepoTags[1])
		end
	end

	if #xjson > 0 then
		print(cjson.encode(xjson))
	else
		print('[]')
	end
	return true
end

--list images
function images_get(param)
	local curl_req_param = {
		uri = ikL_format_url('/images/json?all=1'),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)
	local xjson = {}
	for _,t in ipairs(json) do
		if type(t.RepoTags) == "table" and t.RepoTags[1] then
			local name, tag = t.RepoTags[1]:match("([^:]+):([^:]+)")
			local id = t.Id:match(":([^:]+)")
			if name then
				local _t = {
					created = t.Created,
					id = id,
					name = name,
					tag = tag,
					size = t.Size,
				}

				table.insert(xjson, _t)
			end
		end
	end

	if #xjson > 0 then
		print(cjson.encode(xjson))
	else
		print('[]')
	end
	return true
end

function images_del(param)
	for _id in param.id:gmatch("[^,]+") do
		local curl_req_param = {
			uri = ikL_format_url('/images/%s?force=true', _id),
			method = "DELETE",
		}
		local status, head, data = curl_request(curl_req_param)
		ikL_assert_response(status == 200, data)
	end
end

--list images
function images_search(param)
	local curl_req_param = {
		uri = ikL_format_url('/images/search?term=%s&limit=100', param.keyword),
		method = "GET",
	}

	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = verify_is_json(data)

	print(data)
	return true
end

local pull_chunk_info = {}
function images_pull_status()
	local tmp = DOCKER_PULL_STATUS .. ".tmp"
	local f = io.open(tmp, "w")
	if f then
		for k,v in ipairs(pull_chunk_info) do
			if v.id then
				if v.status == "Downloading" then
					--print(str_format("%s: %s %s", v.id, v.status, v.progress))
					f:write(str_format("%s: %s %s\n", v.id, v.status, v.progress))
				else
					--print(str_format("%s: %s", v.id, v.status))
					f:write(str_format("%s: %s\n", v.id, v.status))
				end
			else
				if v.status then
					--print(str_format("%s",v.status))
					f:write(str_format("%s\n",v.status))
				elseif v.errorDetail then
					--print(str_format("%s",v.errorDetail.message))
					f:write(str_format("%s\n",v.errorDetail.message))
				end
			end
		end
		f:close()
		os.rename(tmp, DOCKER_PULL_STATUS)
	end
end
function images_pull_chunk(ptr, size, nmemb, stream)
	local bytes = size * nmemb
	local ret, json = pcall(cjson.decode, ffi.string(ptr, bytes))
	if ret then
		local hit = false
		if json.id then
			for k,v in ipairs(pull_chunk_info) do
				if v.id == json.id then
					hit = true
					pull_chunk_info[k] = json
					break
				end
			end
		end
		if not hit then
			table.insert(pull_chunk_info, json)
		end
	end
	--print(ffi.string(ptr, bytes))
	images_pull_status()
	return bytes
end

function images_pull(param)
	local fd = flock.lock(DOCKER_PULL_LOCK, flock.LOCK_EX+flock.LOCK_NB)
	if fd >= 0 then
		local curl_req_param = {
			uri = ikL_format_url('/images/create?fromImage=%s&tag=%s', param.name, param.tag or "latest"),
			method = "POST",
			writefunc = ffi.cast("size_t (*)(char *, size_t, size_t, void *)", images_pull_chunk),
		}

		curl_request(curl_req_param)
		table.insert(pull_chunk_info, {status="Finished"})
		images_pull_status()
		flock.unlock(fd)
	end

	return true
end

local image_export_f
function images_export_chunk(ptr, size, nmemb, stream)
	local bytes = size * nmemb
	if image_export_f then
		image_export_f:write(ffi.string(ptr, bytes))
	end
	return bytes
end
function images_export(param)
	if not param.name then
		print("Need param name")
		return false
	end
	if not param.savepath then
		print("Need param savepath")
		return false
	end
	if param.savepath:match("%.%.") then
		print("Invalid param savepath")
		return false
	end

	local curl_req_param = {
		uri = ikL_format_url('/images/%s:%s/get', param.name, param.tag or "latest"),
		method = "GET",
		writefunc = ffi.cast("size_t (*)(char *, size_t, size_t, void *)", images_export_chunk),
	}

	local savepath = str_format("%s/%s", DISK_USER, param.savepath)
	local dirname = str_format("%s ",savepath)
	dirname = ffi.string(C.dirname(ffi.cast("char *",dirname)))

	if dirname == DISK_USER then
		print("Invalid param savepath")
		return false
	end
	if not ikL_existfile(dirname) then
		print("Not existent directory: " .. dirname)
		return false
	end

	local f, err = io.open(savepath..".tmp", "w")
	if not f then
		if err then
		print(savepath..".tmp")
			print(err:match("^[^:]+: (.*)"))
		else
			print("open file failed")
		end
		return false
	end
	image_export_f = f
	local status, head, data = curl_request(curl_req_param)
	f:close()

	if status == 200 then
		os.rename(savepath .. ".tmp", savepath .. ".tar")
	else
		os.remove(savepath .. ".tmp")
	end

	ikL_assert_response(status == 200, data)
	return true
end
 
function _contailner_get_cpuused()
	local f = io.open(DOCKER_CPU_USED_PATH)
	local t = {}
	if f then
		for line in f:lines() do
			local id, used = str_match(line, "^([^ ]+) ([^ ]+)")
			if id then
				t[id] = used
			end
		end
		f:close()
	end

	return t
end

function container_cpuused(param)
	local cpu_used = _contailner_get_cpuused()
	print(cjson.encode(cpu_used))
end

function container_get_meminfo(id)
	local stat_path = str_format("%s/%s/memory.stat", DOCKER_MEM_PATH, id)
	local f = io.open(stat_path)
	local rss, total
	if f then
		for line in f:lines() do
			local k, v = line:match("([^ ]+) (%d+)")
			if k then
				if k == "rss" then
					rss = tonumber(v)
				elseif k == "hierarchical_memory_limit" then
					total = tonumber(v)
					--beyond 1000G
					if total > 1073741824000 then
						total = 0
					end
				end
			end
		end
		f:close()
	end

	return rss, total
end

function container_get_log(param)
	local curl_req_param = {
		uri = ikL_format_url('/containers/%s/logs?tail=1000&stdout=true&stderr=true', param.id),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local json = {}
	for line in data:gmatch("([^\r\n]+)") do
		table.insert(json, line)
	end
	print(cjson.encode(json))
end

function container_get_top(param)
	local curl_req_param = {
		uri = ikL_format_url('/containers/%s/top?ps_args=h', param.id),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)
	print(data)
	local json = verify_is_json(data)
	print(cjson.encode(json))
end

function container_get(param)
	local curl_req_param = {
		uri = ikL_format_url('/containers/json?all=1'),
		method = "GET",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)

	local cpu_used = _contailner_get_cpuused()
	local json = verify_is_json(data)
	local xjson = {}
	for _,t in ipairs(json) do
		local interface
		local netinfo
		local ipaddr, mac, gateway, ip6addr, ip6gateway
		for iface,v in pairs(t.NetworkSettings.Networks) do
			interface = iface
			netinfo = v
			break
		end
		if interface and netinfo then
			ipaddr = netinfo.IPAddress
			ip6addr = netinfo.GlobalIPv6Address
			if ipaddr == "" and type(netinfo.IPAMConfig) == "table" then
				if netinfo.IPAMConfig.IPv4Address then
					ipaddr = netinfo.IPAMConfig.IPv4Address
				end
				if netinfo.IPAMConfig.IPv6Address then
					ip6addr = netinfo.IPAMConfig.IPv6Address
				end
			end

			gateway = netinfo.Gateway
			ip6gateway = netinfo.IPv6Gateway
			mac = netinfo.MacAddress
		end

		if t.Names[1] then
			local memused, memory = container_get_meminfo(t.Id)
			local _t = {
				id = t.Id,
				name = t.Names[1]:sub(2),
				created = t.Created,
				state = t.State,
				status = t.Status,
				image = t.Image,
				interface = interface or "",
				ipaddr = ipaddr or "",
				gateway = gateway or "",
				ip6addr = ip6addr,
				ip6gateway = ip6gateway,
				mac = mac or "",
				auto_start = t.Labels.auto_start or "0",
				comment = t.Labels.comment or "",
				mounts = t.Labels.mounts or "",
				env = t.Labels.env or "",
				cmd = t.Labels.cmd or "",
				cpu_used = cpu_used[t.Id] or "0.00%",
				memused = memused or 0,
				memory = memory or 0,
			}

			table.insert(xjson, _t)
		end
	end

	if #xjson > 0 then
		print(cjson.encode(xjson))
	else
		print('[]')
	end
	--print(data)
	return true
end

function container_update(param)

	local curl_req_param = {
		uri = ikL_format_url('/containers/%s/json', param.id),
		method = "GET",
	}

	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 200, data)
	local json = verify_is_json(data)

	if param.memory then
		local post_t = {
			Memory = tonumber(param.memory),
		}
		local curl_req_param = {
			uri = ikL_format_url("/containers/%s/update", param.id),
			method = "POST",
			heads = {
				["Content-Type"] = "application/json",
			},
			postdata = cjson.encode(post_t),
		}
		local status, head, data = curl_request(curl_req_param)
		ikL_assert_response(status == 200, data)
	end

	for iface,v in pairs(json.NetworkSettings.Networks) do
		local network_param = { id=iface, cid=param.id}
		__network_disconnect(network_param)
	end

	if param.interface then
		local network_param = { id=param.interface, cid=param.id, ipaddr=param.ipaddr, ip6addr=param.ip6addr }
		network_connect(network_param)
	end
end

function container_add(param)
	if not param.name then
		print("invalid param name")
		return false
	end

	local restart_always = ""
	if param.auto_start == "1" then
		restart_always = "unless-stopped"
	end
	local Binds = convert_to_table(param.mounts, "[^,]+", 0)
	if Binds then
		for i,v in ipairs(Binds) do
			local s,d = v:match("([^:]+):(.+)")
			if s then
				if not ikL_existfile(DISK_USER .. s) then
					print("target directory not found: ".. s)
					return false
				else
					Binds[i] = str_format("%s%s:%s",DISK_USER,s,d)
				end
			end
		end
	end

	local post_t = {
		HostConfig = {
			Binds = Binds,
			Memory = tonumber(param.memory),
			NetworkMode = param.interface,
			RestartPolicy = {
				Name = restart_always,
				MaximumRetryCount = 0,
			}
		},
		Hostname = param.name,
		Cmd = convert_to_command(param.cmd),
		Env = convert_to_table(param.env, "[^,]+", 1),
		Tty = true,
		Image = param.image,
		Labels = { interface=param.interface, comment = param.comment, env=param.env, cmd=param.cmd, mounts=param.mounts, auto_start=param.auto_start },
	}

	if param.ipaddr or param.ip6addr then
		post_t.NetworkingConfig = { EndpointsConfig = { [param.interface] = { IPAMConfig = { IPv4Address = param.ipaddr, IPv6Address = param.ip6addr } } } }
	end

	local curl_req_param = {
		uri = ikL_format_url("/containers/create?name=" .. param.name),
		method = "POST",
		heads = {
			["Content-Type"] = "application/json",
		},
		postdata = cjson.encode(post_t),
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 201, data)

	local json = verify_is_json(data)
	print(json.Id)

	if param.auto_start == "1" then
		local curl_req_param = {
			uri = ikL_format_url('/containers/%s/start', param.name),
			method = "POST",
		}
		curl_request(curl_req_param)
	end

	return true
end

function container_del(param)
	for _id in param.id:gmatch("[^,]+") do
		local curl_req_param = {
			uri = ikL_format_url('/containers/%s?force=1', _id),
			method = "DELETE",
		}
		local status, head, data = curl_request(curl_req_param)
		ikL_assert_response(status == 204, data)
	end
end

function container_start(param)
	for _id in param.id:gmatch("[^,]+") do
		local curl_req_param = {
			uri = ikL_format_url('/containers/%s/start', _id),
			method = "POST",
		}
		local status, head, data = curl_request(curl_req_param)
		ikL_assert_response(status == 204, data)
	end
end

function container_stop(param)
	for _id in param.id:gmatch("[^,]+") do
		local curl_req_param = {
			uri = ikL_format_url('/containers/%s/stop', _id),
			method = "POST",
		}
		local status, head, data = curl_request(curl_req_param)
		ikL_assert_response(status == 204, data)
	end
end

function container_rename(param)
	local curl_req_param = {
		uri = ikL_format_url('/containers/%s/rename?name=%s', param.id, param.name),
		method = "POST",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 204, data)
	return true
end

function container_commit(param)
	local curl_req_param = {
		uri = ikL_format_url('/commit?container=%s&repo=%s&tag=%s', param.id, param.name, param.tag or "latest"),
		method = "POST",
		heads = {
			["Content-Type"] = "application/json",
		},
		postdata = "",
	}
	local status, head, data = curl_request(curl_req_param)
	ikL_assert_response(status == 201, data)

	return true
end


function verify_is_json(data)
	local ret, json = pcall(cjson.decode, data)
	ikL_assert(ret, "internal error, verify json err")
	return json
end

function convert_to_command(s)
	if s and #s > 0 then
		local eye = false
		local buf
		local t = {}
		s = url_decode(s)
		for m in s:gmatch("[^ ]+") do
			local x
			if buf then
				if m:match("[\"']") then
					buf = buf .. " " .. m
					x = buf
					buf = nil
				else
					buf = buf .. " " .. m
				end
			else
				if m:match("[\"']") then
					local c2 = m:sub(-1)
					if c2 == "'" or c2 == '"' then
						x = m
					else
						buf = m
					end
				else
					x = m
				end
			end

			if x then
				x = x:gsub("[\"']","")
				table.insert(t, x)
			end
		end
		return t
	end
	return nil
end

function convert_to_table(s, syntax, decode)
	if s and #s > 0 then
		local t = {}
		if decode == -1 then
			s = url_decode(s)
		end
		for m in s:gmatch(syntax) do
			if decode == 1 then
				table.insert(t, url_decode(m))
			else
				table.insert(t, m)
			end
		end
		return t
	end
	return nil
end

function ikL_format_url(fmt, ...)
	return string.format('http://v1.29' .. fmt, ...)
end

function ikL_assert_response(ret, data)
	if not ret then
		local json = verify_is_json(data)
		if json.message then
			print(json.message)
		end
		os.exit(1)
	end
end

function ikL_assert(ret, msg)
	if not ret then
		print(msg)
		os.exit(1)
	end
end

function ikL_headers(data)
	local n = 0
	local t = {}
	for line in data:gmatch("([^\r\n]+)\r\n") do
		n = n + 1
		if n == 1 then
			local status = line:match("[^ ]+ ([^ ]+)")
			t.status = tonumber(status)
		else
			local k,v = line:match("([^ ]+): +(.+)")
			if k and v then
				t[k] = v
			end
		end
	end
	return t
end

function ikL_parser_arg()
	local t = {}

	for i, v in ipairs(arg) do
		if i > 1 then
			local a, b = str_match(v,"^([^ =]+)=(.+)")
			if a then
				t[a] = b
			else
				t[v] = true
			end
		end
	end

	return t
end

function ikL_existfile(file)
	return (C.access(file, 0) == 0)
end

function main()
	if not arg[1] then os.exit(1) end
	local FUNCTION = {
		network_get = network_get,
		network_get_list = network_get_list,
		network_add = network_add,
		network_del = network_del,
		network_edit = network_edit,
		network_inspect = network_inspect,
		network_get_name = network_get_name,
		network_connect = network_connect,
		network_disconnect = network_disconnect,
		container_get = container_get,
		container_add = container_add,
		container_del = container_del,
		container_start  = container_start,
		container_stop   = container_stop,
		container_rename = container_rename,
		container_cpuused = container_cpuused,
		container_commit = container_commit,
		container_update = container_update,
		container_get_log = container_get_log,
		container_get_top = container_get_top,
		images_get = images_get,
		images_get_info = images_get_info,
		images_get_name = images_get_name,
		images_search = images_search,
		images_pull = images_pull,
		images_del = images_del,
		images_export = images_export,
	}

	local func = FUNCTION[arg[1]]
	if func then
		local param = ikL_parser_arg()
		local result = (func(param) ~= false)
		os.exit(result)
	else
		print("unknown command " .. arg[1])
		os.exit(1)
	end
end

--[[
./ikdocker.lua network_add name=test subnet=192.168.200.0/24 gateway=192.168.200.1 comment=123
./ikdocker.lua network_del id=
./ikdocker.lua container_add image="i386/ubuntu" env="a=1,b=2" cmd="/bin/bash,--login" comment=1111 mounts="/sdb/xxx:/fff" auto_start=1 memory=100 name=x0 interface=222
./ikdocker.lua container_stop  id=
./ikdocker.lua container_start id=
./ikdocker.lua container_del   id=
./ikdocker.lua container_del   id=
--]]

main()

