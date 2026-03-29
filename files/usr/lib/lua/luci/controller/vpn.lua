module("luci.controller.vpn", package.seeall)

require("luci.model.uci")

-- Load i18n from external files (shared with settings.htm)
local i18n_dir = "/usr/lib/lua/luci/view/vpn/i18n/"
local function load_i18n(code)
    local ok, data = pcall(dofile, i18n_dir .. code .. ".lua")
    if ok and data then return data end
    return nil
end

local i18n = setmetatable({}, {
    __index = function(t, lang)
        local data = load_i18n(lang)
        if data then rawset(t, lang, data) end
        return data
    end
})
-- Pre-load English as fallback
i18n["en"] = load_i18n("en") or {
    title = "VPN Settings",
    vpn = "VPN",
    vpn_settings = "VPN Settings",
    vpn_status = "VPN Status",
        enabled = "Enabled",
        disabled = "Disabled",
        connecting = "Connecting",
        connected = "Connected",
        disconnected = "Disconnected",
        split_tunnel = "Split Tunneling",
        split_tunnel_desc = "Route domestic traffic directly, foreign traffic via VPN",
        vpn_server = "VPN Server",
        connect = "Connect",
        disconnect = "Disconnect",
        reconnect = "Reconnect",
        save = "Save",
        cancel = "Cancel",
        apply = "Apply",
        refresh = "Refresh",
        loading = "Loading...",
        error = "Error",
        success = "Success",
        connection_failed = "Connection failed",
        connection_success = "Connection established",
        please_wait = "Please wait...",
        checking = "Checking...",
        no_servers = "No servers available",
        server_list = "Server List",
        latency = "Latency",
        update_ip_ranges = "Update IP Ranges",
        last_updated = "Last updated",
        never = "Never",
        count = "Count",
        routes_updated = "Routes updated",
        routes_count = "routes",
        domestic_traffic = "Domestic Traffic",
        foreign_traffic = "Foreign Traffic",
        vpn_exit = "VPN Exit",
        update_now = "Update Now",
        detecting = "Detecting location...",
        detected = "Detected",
        your_ip = "Your IP",
        your_country = "Your Country",
        auto_detect = "Auto-detect",
        detected_success = "Location detected",
        detection_failed = "Detection failed",
        real_ip = "Real IP (before VPN)",
        vpn_ip = "VPN IP",
        location = "Location",
        ip_ranges_loaded = "IP ranges loaded",
        retry = "Retry",
        login = "Login",
        logout = "Logout",
        username = "Username",
        password = "Password",
        login_title = "VIP Account Login",
        login_desc = "Enter your account credentials to connect VPN",
        login_button = "Login & Connect",
        logout_button = "Logout & Disconnect",
        invalid_credentials = "Invalid username or password",
        account_expired = "Account has expired",
        not_vip_account = "This account is not a VIP account",
        logged_in = "Logged In",
        logged_out = "Not Logged In",
        expired = "Expired",
        not_vip = "Not VIP",
        login_required = "Login Required",
        user_status = "User Status",
        vip_user = "VIP User",
        valid_until = "Valid Until",
        auto_connect = "Auto-connect when VIP",
        checking_status = "Checking status...",
        renew_now = "Renew Now",
        select_server = "Select Server",
        refresh_servers = "Refresh Servers",
        servers_updated = "Servers updated",
        servers_count = "servers",
        split_off = "Off",
        split_forward = "Forward Split",
        split_forward_desc = "Local country direct, rest via VPN",
        split_reverse = "Reverse Split",
        split_reverse_desc = "Only VPN server country IPs via VPN, rest direct. For best results, set device DNS to a server in that country."
}
-- END of inline en fallback; other languages loaded on-demand from i18n/*.lua

    local countries = {
        {code = "cn", name = "China", flag = "🇨🇳"},
        {code = "jp", name = "Japan", flag = "🇯🇵"},
        {code = "us", name = "United States", flag = "🇺🇸"},
        {code = "kr", name = "South Korea", flag = "🇰🇷"},
        {code = "hk", name = "Hong Kong", flag = "🇭🇰"},
        {code = "tw", name = "Taiwan", flag = "🇹🇼"},
        {code = "sg", name = "Singapore", flag = "🇸🇬"},
        {code = "my", name = "Malaysia", flag = "🇲🇾"},
        {code = "th", name = "Thailand", flag = "🇹🇭"},
        {code = "vn", name = "Vietnam", flag = "🇻🇳"},
        {code = "id", name = "Indonesia", flag = "🇮🇩"},
        {code = "ph", name = "Philippines", flag = "🇵🇭"},
        {code = "in", name = "India", flag = "🇮🇳"},
        {code = "pk", name = "Pakistan", flag = "🇵🇰"},
        {code = "bd", name = "Bangladesh", flag = "🇧🇩"},
        {code = "ae", name = "UAE", flag = "🇦🇪"},
        {code = "sa", name = "Saudi Arabia", flag = "🇸🇦"},
        {code = "tr", name = "Turkey", flag = "🇹🇷"},
        {code = "ru", name = "Russia", flag = "🇷🇺"},
        {code = "de", name = "Germany", flag = "🇩🇪"},
        {code = "gb", name = "United Kingdom", flag = "🇬🇧"},
        {code = "fr", name = "France", flag = "🇫🇷"},
        {code = "nl", name = "Netherlands", flag = "🇳🇱"},
        {code = "au", name = "Australia", flag = "🇦🇺"},
        {code = "ca", name = "Canada", flag = "🇨🇦"},
        {code = "br", name = "Brazil", flag = "🇧🇷"}
    }

function get_lang()
    local uci = require("luci.model.uci").cursor()
    local lang = uci:get("luci", "main", "lang") or "auto"
    lang = lang:gsub("%s+", "")

    if lang == "" or lang == "auto" then
        local accept = luci.http.getenv("HTTP_ACCEPT_LANGUAGE") or ""
        local primary = accept:match("^([^,;]+)")
        if primary then
            primary = primary:gsub("%s+", ""):lower()
            local browser_map = {
                zh = "zh-CN", ["zh-cn"] = "zh-CN", ["zh-hans"] = "zh-CN",
                ["zh-tw"] = "zh-TW", ["zh-hk"] = "zh-TW", ["zh-hant"] = "zh-TW",
                ja = "ja", ko = "ko", de = "de", fr = "fr", es = "es",
                pt = "pt", ru = "ru", ar = "ar", fa = "fa", hi = "hi",
                id = "id", th = "th", tr = "tr", vi = "vi"
            }
            local short = primary:match("^(%a+%-?%a*)")
            lang = browser_map[short] or browser_map[short:match("^(%a+)")] or "en"
        else
            lang = "en"
        end
    end

    local lang_map = {
        zh_Hans = "zh-CN", zh_Hant = "zh-TW",
        ["zh-cn"] = "zh-CN", ["zh-tw"] = "zh-TW",
        zh_cn = "zh-CN", zh_tw = "zh-TW",
        pt_br = "pt", pt_BR = "pt"
    }
    return lang_map[lang] or lang
end

function get_country_name(code)
    for _, c in ipairs(countries) do
        if c.code == code then
            return c.name
        end
    end
    return code
end

function get_country_flag(code)
    for _, c in ipairs(countries) do
        if c.code == code then
            return c.flag
        end
    end
    return ""
end

function index()
    local lang = get_lang and get_lang() or "en"
    local i = i18n[lang] or i18n["en"]
    entry({"admin", "services", "vpn"}, alias("admin", "services", "vpn", "settings"), i.vpn or "VPN", 50)
    entry({"admin", "services", "vpn", "settings"}, template("vpn/settings"), i.vpn_settings or "VPN Settings", 10)
    entry({"admin", "services", "vpn", "api"}, call("api_get_vpn_status"), nil, 20)
    entry({"admin", "services", "vpn", "api_connect"}, call("api_connect"), nil, 21)
    entry({"admin", "services", "vpn", "api_set_split"}, call("api_set_split_tunnel"), nil, 22)
    entry({"admin", "services", "vpn", "api_detect"}, call("api_auto_detect"), nil, 23)
    entry({"admin", "services", "vpn", "api_update_ips"}, call("api_update_ips"), nil, 24)
    entry({"admin", "services", "vpn", "api_login"}, call("api_login"), nil, 25)
    entry({"admin", "services", "vpn", "api_logout"}, call("api_logout"), nil, 26)
    entry({"admin", "services", "vpn", "api_auth_status"}, call("api_auth_status"), nil, 27)
    entry({"admin", "services", "vpn", "api_renewal"}, call("api_get_renewal_url"), nil, 28)
    entry({"admin", "services", "vpn", "api_servers"}, call("api_get_servers"), nil, 29)
    entry({"admin", "services", "vpn", "api_set_server"}, call("api_set_server"), nil, 30)
end

function api_get_vpn_status()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local current_country = util.exec("/usr/sbin/vipin-country-ips get-country 2>/dev/null"):gsub("%s+", "")
    local ip_count = util.exec("/usr/sbin/vipin-country-ips count " .. current_country .. " 2>/dev/null"):gsub("%s+", "")
    local vpn_enabled = luci.model.uci:get("vipin", "vpn", "enabled") or "0"
    local split_enabled = luci.model.uci:get("vipin", "vpn", "split_tunnel") or "1"
    local split_mode = luci.model.uci:get("vipin", "vpn", "split_mode") or "forward"
    local vpn_connected = util.exec("pgrep openconnect >/dev/null && echo '1' || echo '0'"):gsub("%s+", "")
    
    local detect_info = util.exec("/usr/sbin/vipin-detect info 2>/dev/null")
    local detected = false
    local detected_ip = ""
    local detected_country = ""
    local detect_time = ""
    
    if detect_info and detect_info ~= "" then
        detected_ip = string.match(detect_info, '"ip":%s*"([^"]*)"') or ""
        detected_country = string.match(detect_info, '"country":%s*"([^"]*)"') or ""
        detect_time = string.match(detect_info, '"detect_time":%s*"([^"]*)"') or ""
        detected = string.match(detect_info, '"detected":%s*true') ~= nil
    end
    
    if detected_country == "" then
        detected_country = current_country
    end
    
    -- VPN server country (extracted from server domain, e.g. "cn" from "cn.fanq.in")
    local server = luci.model.uci:get("vipin", "vpn", "server") or ""
    local server_country = server:match("^([^.]+)") or ""
    local server_ip_count = 0
    if server_country ~= "" then
        server_ip_count = tonumber(util.exec("/usr/sbin/vipin-country-ips count " .. server_country .. " 2>/dev/null"):gsub("%s+", "")) or 0
    end

    local lang_key = get_lang()
    local extra = i18n[lang_key] or i18n["en"]

    local status = {
        vpn_enabled = (vpn_enabled == "1"),
        vpn_connected = (vpn_connected == "1"),
        split_tunnel = (split_enabled == "1"),
        split_mode = split_mode,
        current_country = current_country,
        current_country_name = get_country_name(current_country),
        current_country_flag = get_country_flag(current_country),
        ip_count = tonumber(ip_count) or 0,
        countries = countries,
        detected = detected,
        detected_ip = detected_ip,
        detected_country = detected_country,
        detected_country_name = get_country_name(detected_country),
        detected_country_flag = get_country_flag(detected_country),
        detect_time = detect_time,
        server_country = server_country,
        server_country_name = get_country_name(server_country),
        server_country_flag = get_country_flag(server_country),
        server_ip_count = server_ip_count,
        translations = i18n[get_lang()] or i18n["en"],
        extra = extra
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(status))
end

function api_connect()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local action = luci.http.formvalue("action") or "connect"
    local result = {success = false, message = ""}
    
    if action == "connect" then
        local output = util.exec("/etc/init.d/vipin-vpn start 2>&1")
        result.success = (util.exec("pgrep openconnect >/dev/null && echo 1 || echo 0"):gsub("%s+", "") == "1")
    elseif action == "disconnect" then
        util.exec("/etc/init.d/vipin-vpn stop 2>&1")
        result.success = true
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_set_split_tunnel()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")

    local mode = luci.http.formvalue("mode") or "off"
    local result = {success = false}

    if mode == "off" then
        luci.model.uci:set("vipin", "vpn", "split_tunnel", "0")
    else
        luci.model.uci:set("vipin", "vpn", "split_tunnel", "1")
        luci.model.uci:set("vipin", "vpn", "split_mode", mode)
    end
    luci.model.uci:save("vipin")
    luci.model.uci:commit("vipin")

    if mode == "off" then
        util.exec("/usr/sbin/vipin-vpn-routing disable 2>&1")
    else
        util.exec("/usr/sbin/vipin-vpn-routing reload 2>&1")
    end

    result.success = true
    result.mode = mode

    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_auto_detect()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local output = util.exec("/usr/sbin/vipin-detect auto 2>&1")
    
    local success = string.match(output, '"success":%s*true') ~= nil
    local detected_ip = string.match(output, '"ip":%s*"([^"]*)"') or ""
    local country_code = string.match(output, '"country_code":%s*"([^"]*)"') or ""
    local country = string.match(output, '"country":%s*"([^"]*)"') or ""
    local ip_count = tonumber(string.match(output, '"ip_count":%s*([0-9]+)')) or 0
    
    local result = {
        success = success,
        detected_ip = detected_ip,
        country_code = country_code,
        country = country,
        country_name = get_country_name(country),
        country_flag = get_country_flag(country),
        ip_count = ip_count,
        message = success and "Detection successful" or "Detection failed"
    }
    
    if success then
        util.exec("/usr/sbin/vipin-vpn-routing reload 2>&1")
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_update_ips()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local country = util.exec("/usr/sbin/vipin-country-ips get-country 2>/dev/null"):gsub("%s+", "")
    local output = util.exec("/usr/sbin/vipin-country-ips update " .. country .. " 2>&1")
    local ip_count = util.exec("/usr/sbin/vipin-country-ips count " .. country .. " 2>/dev/null"):gsub("%s+", "")
    
    local result = {
        success = true,
        country = country,
        country_name = get_country_name(country),
        country_flag = get_country_flag(country),
        ip_count = tonumber(ip_count) or 0,
        message = output
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_login()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local username = luci.http.formvalue("username") or ""
    local password = luci.http.formvalue("password") or ""
    
    -- Escape single quotes to prevent shell injection
    local safe_user = username:gsub("'", "'\\''")
    local safe_pass = password:gsub("'", "'\\''")
    local result_json = util.exec("/usr/sbin/vipin-auth login '" .. safe_user .. "' '" .. safe_pass .. "' 2>/dev/null")
    
    local success = string.match(result_json, '"status": "valid"') ~= nil
    local status = string.match(result_json, '"status": "([^"]+)"') or "error"
    local message = string.match(result_json, '"message": "([^"]+)"') or ""
    local user_type = string.match(result_json, '"type": "([^"]+)"') or ""
    local expiration = string.match(result_json, '"expiration": "([^"]+)"') or ""
    
    local result = {
        success = success,
        status = status,
        message = message,
        username = username,
        type = user_type,
        expiration = expiration
    }
    
    if success then
        local server = luci.http.formvalue("server") or ""
        -- Ensure vipin config section exists
        if not luci.model.uci:get("vipin", "vpn") then
            luci.model.uci:set("vipin", "vpn", "vpn")
        end
        luci.model.uci:set("vipin", "vpn", "enabled", "1")
        luci.model.uci:set("vipin", "vpn", "username", username)
        -- Use provided server, existing config, or default
        if server == "" then
            server = luci.model.uci:get("vipin", "vpn", "server") or "jp.fanq.in"
        end
        luci.model.uci:set("vipin", "vpn", "server", server)
        luci.model.uci:save("vipin")
        luci.model.uci:commit("vipin")
        -- Start VPN and auth monitor
        util.exec("/etc/init.d/vipin-vpn start 2>&1")
        util.exec("/etc/init.d/vipin-auth start 2>&1")
    end
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_logout()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    -- Disable auto-connect
    luci.model.uci:set("vipin", "vpn", "enabled", "0")
    luci.model.uci:save("vipin")
    luci.model.uci:commit("vipin")
    -- Stop services
    util.exec("/etc/init.d/vipin-vpn stop 2>&1")
    util.exec("/etc/init.d/vipin-auth stop 2>&1")
    util.exec("/usr/sbin/vipin-auth logout 2>/dev/null")

    local result = {
        success = true,
        message = "Logged out successfully"
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_auth_status()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local status_json = util.exec("/usr/sbin/vipin-auth status 2>/dev/null")
    
    local logged_in = string.match(status_json, '"logged_in":%s*true') ~= nil
    local reason = string.match(status_json, '"reason":%s*"([^"]+)"') or ""
    local username = string.match(status_json, '"username":%s*"([^"]+)"') or ""
    local user_type = string.match(status_json, '"type":%s*"([^"]+)"') or ""
    local expiration = string.match(status_json, '"expiration":%s*"([^"]+)"') or ""
    local auth_time = string.match(status_json, '"auth_time":%s*"([^"]+)"') or ""
    
    local result = {
        logged_in = logged_in,
        reason = reason,
        username = username,
        type = user_type,
        expiration = expiration,
        auth_time = auth_time,
        i18n = (function()
            local t = i18n[get_lang()] or i18n["en"]
            return {
                logged_in = t.logged_in or "Logged In",
                logged_out = t.logged_out or "Not Logged In",
                expired = t.expired or "Expired",
                not_vip = t.not_vip or "Not VIP",
                login_required = t.login_required or "Login Required"
            }
        end)()
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_get_renewal_url()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local result_json = util.exec("/usr/sbin/vipin-auth renewal-url 2>/dev/null")
    
    local success = string.match(result_json, '"success":%s*true') ~= nil
    local error_msg = string.match(result_json, '"error":%s*"([^"]+)"') or ""
    local url = string.match(result_json, '"url":%s*"([^"]+)"') or ""
    local username = string.match(result_json, '"username":%s*"([^"]+)"') or ""
    local token = string.match(result_json, '"token":%s*"([^"]+)"') or ""
    
    local result = {
        success = success,
        error = error_msg,
        url = url,
        username = username,
        token = token
    }
    
    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_get_servers()
    local http = require("luci.http")
    local util = require("luci.util")

    -- Fetch server list from website API (public, no auth needed)
    local response = util.exec("wget -q -O- --timeout=10 'https://www.anyfq.com/api/v1/servers/list' 2>/dev/null")

    if response and response ~= "" then
        http.prepare_content("application/json")
        http.write(response)
    else
        -- Fallback: return empty array, frontend will use local data
        http.prepare_content("application/json")
        http.write("[]")
    end
end

function api_set_server()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")

    local server = luci.http.formvalue("server") or ""

    local success = false
    local reconnected = false
    if server and server ~= "" then
        luci.model.uci:set("vipin", "vpn", "server", server)
        luci.model.uci:save("vipin")
        luci.model.uci:commit("vipin")
        success = true

        -- If VPN is running, reconnect to new server
        local vpn_running = util.exec("pgrep openconnect >/dev/null && echo '1' || echo '0'"):gsub("%s+", "")
        if vpn_running == "1" then
            util.exec("/etc/init.d/vipin-vpn stop 2>&1")
            util.exec("sleep 1")
            util.exec("/etc/init.d/vipin-vpn start 2>&1")
            reconnected = true
        end
    end

    local result = {
        success = success,
        server = server,
        reconnected = reconnected
    }

    http.prepare_content("application/json")
    http.write(json.encode(result))
end
