local M = {}

local cached_token = nil
local token_path = "/tmp/iktmp/extapi.token"

local function get_token()
    if cached_token then
        return cached_token
    end

    local f = io.open(token_path, "r")
    if not f then
        return nil
    end

    local token = f:read("*all")
    f:close()

    token = token:gsub("%s+", "")
    cached_token = token
    return token
end

function M.ApiCall(cookie, username)
    ngx.req.read_body()

    local res, call_json_tab = pcall(cjson.decode, ngx.var.request_body)
    if not res then
        ikngx.senderror(10007, "decode json fail")
    end

    local token = call_json_tab["auth_token"]
    local apiTokenStr = get_token()
    if token ~= apiTokenStr then
        ngx.exit(ngx.HTTP_UNAUTHORIZED)
    end

    call_json_tab["func_name"] = "plugin_extapi"

    local env = {
        IKREST_USER = "extapi",
        IKREST_REFERER = "ik-http-server",
        IKREST_REMOTE_ADDR = ngx.var.remote_addr,
    }

    local ok, buf = ikngx.rest(call_json_tab, env)
    ngx.header["Content-Type"]  = "application/json;charset=UTF-8"

    if ok then
        ngx.header["Content-Length"] = #buf
        ngx.print(buf)
    else
        ikngx.senderror2(ResIkrestErr, buf)
    end

    ngx.exit(0)
end

return M
