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
        update_account = "Update Account",
        login_title = "VIP Account Login",
        login_desc = "Enter your account credentials to connect VPN",
        login_button = "Save Account",
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
    entry({"admin", "services", "vpn", "api_video_status"},  call("api_video_status"),  nil, 31)
    entry({"admin", "services", "vpn", "api_video_refresh"}, call("api_video_refresh"), nil, 32)
    entry({"admin", "services", "vpn", "api_video_toggle"},  call("api_video_toggle"),  nil, 33)
    entry({"admin", "services", "vpn", "api_video_add"},     call("api_video_add"),     nil, 34)
    entry({"admin", "services", "vpn", "api_video_remove"},  call("api_video_remove"),  nil, 35)
end

function api_get_vpn_status()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")
    
    local current_country = util.exec("/usr/sbin/vipin-country-ips get-country 2>/dev/null"):gsub("%s+", "")
    local ip_count = util.exec("/usr/sbin/vipin-country-ips count " .. current_country .. " 2>/dev/null"):gsub("%s+", "")
    local split_enabled = luci.model.uci:get("vipin", "vpn", "split_tunnel") or "1"
    local split_mode = luci.model.uci:get("vipin", "vpn", "split_mode") or "forward"
    -- Ground truth: tun0 exists + both userspace components alive. procd's
    -- status wrapper only reports procd-managed instances, so a manually
    -- launched or externally-restarted stack would be invisible to it.
    -- Checking actual state is more reliable.
    local tun0_up = util.exec("ip link show tun0 2>/dev/null"):find("tun0") ~= nil
    local stunnel_up = util.exec("pgrep -f '/etc/vipin/stunnel-client.conf' 2>/dev/null") ~= ""
    local hev_up = util.exec("pgrep -f hev-socks5-tunnel 2>/dev/null") ~= ""
    local vpn_connected = tun0_up and stunnel_up and hev_up
    local auth_status = luci.model.uci:get("vipin", "vpn", "auth_status") or "ok"
    
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
    -- un.fanq.in is the overseas frontend that forwards CN traffic to cn2,
    -- so it shares cn's IP set and country display — treat as cn alias.
    local server = luci.model.uci:get("vipin", "vpn", "server") or ""
    local server_country = server:match("^([^.]+)") or ""
    if server_country == "un" then server_country = "cn" end
    local server_ip_count = 0
    if server_country ~= "" then
        local server_ip_str = util.exec("/usr/sbin/vipin-country-ips count " .. server_country .. " 2>/dev/null"):gsub("%s+", "")
        server_ip_count = tonumber(server_ip_str) or 0
    end

    local lang_key = get_lang()
    local extra = i18n[lang_key] or i18n["en"]

    local status = {
        vpn_connected = vpn_connected,
        auth_status = auth_status,
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
        result.success = util.exec("ip link show tun0 2>/dev/null"):find("tun0") ~= nil
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

    -- Only apply routing changes if VPN is connected (tun0 is ground truth)
    local vpn_running = util.exec("ip link show tun0 2>/dev/null"):find("tun0") and "1" or "0"
    if vpn_running == "1" then
        if mode == "off" then
            util.exec("/usr/sbin/vipin-vpn-routing disable 2>&1")
        else
            util.exec("/usr/sbin/vipin-vpn-routing reload 2>&1")
        end
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
    local nixio = require("nixio")

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

    local connected = false
    local auth_status

    if success then
        local server = luci.http.formvalue("server") or ""
        -- Ensure vipin config section exists
        if not luci.model.uci:get("vipin", "vpn") then
            luci.model.uci:set("vipin", "vpn", "vpn")
        end
        luci.model.uci:set("vipin", "vpn", "username", username)
        -- Use provided server, existing config, or default
        if server == "" then
            local base_domain = luci.model.uci:get("vipin", "vpn", "base_domain") or "fanq.in"
            server = luci.model.uci:get("vipin", "vpn", "server") or ("jp." .. base_domain)
        end
        luci.model.uci:set("vipin", "vpn", "server", server)
        luci.model.uci:set("vipin", "vpn", "auth_status", "ok")
        luci.model.uci:save("vipin")
        luci.model.uci:commit("vipin")
        auth_status = "ok"

        -- "Save account" semantics: if the VPN stack is already running
        -- (user hit 更新账号 with an active tunnel), tear it down first so
        -- stunnel/hev/stubby pick up the new credentials cleanly. Then
        -- start fresh. Without the stop, stale stunnel keeps the old
        -- session and LuCI shows connected=no until next watchdog tick.
        if util.exec("ip link show tun0 2>/dev/null"):find("tun0") or
           util.exec("pgrep -f /etc/vipin/stunnel-client.conf 2>/dev/null") ~= "" then
            util.exec("/etc/init.d/vipin-vpn stop >/dev/null 2>&1")
            nixio.nanosleep(1, 0)  -- 1s for cleanup
        end
        util.exec("/etc/init.d/vipin-vpn start >/dev/null 2>&1")
        util.exec("/etc/init.d/vipin-auth start >/dev/null 2>&1")

        -- Poll up to 12s for tun0 to exist (ground truth for stack-up).
        for _ = 1, 24 do
            if util.exec("ip link show tun0 2>/dev/null"):find("tun0") then
                connected = true
                break
            end
            nixio.nanosleep(0, 500000000)  -- 500ms
        end
    else
        -- Persist failure reason so api_get_vpn_status reflects it.
        if not luci.model.uci:get("vipin", "vpn") then
            luci.model.uci:set("vipin", "vpn", "vpn")
        end
        luci.model.uci:set("vipin", "vpn", "auth_status", status)
        luci.model.uci:save("vipin")
        luci.model.uci:commit("vipin")
        auth_status = status
    end

    local result = {
        success = success,
        status = status,
        message = message,
        username = username,
        type = user_type,
        expiration = expiration,
        vpn_connected = connected,
        auth_status = auth_status
    }

    http.prepare_content("application/json")
    http.write(json.encode(result))
end

function api_logout()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")

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
    local site_url = luci.model.uci:get("vipin", "vpn", "site_url") or "https://www.anyfq.com"
    local response = util.exec("wget -q -O- --timeout=10 '" .. site_url .. "/api/v1/servers/list' 2>/dev/null")

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

        -- If VPN is running (tun0 exists), reconnect to new server
        if util.exec("ip link show tun0 2>/dev/null"):find("tun0") then
            util.exec("/etc/init.d/vipin-vpn restart >/dev/null 2>&1")
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

-- =========================================================================
-- video_direct RPC actions (Phase 4)
-- =========================================================================

function api_video_status()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")

    local enabled = luci.model.uci:get("vipin", "vpn", "video_direct") or "1"
    local mode = luci.model.uci:get("vipin", "vpn", "split_mode") or "forward"
    local last = luci.model.uci:get("vipin", "vpn", "video_last_refresh") or ""

    -- NOTE: wrap gsub in parens to discard its 2nd return value (replacement
    -- count) which Lua would otherwise pass to tonumber as a base argument.
    -- Use the script's own parse-list subcommand for accurate comment/blank filtering
    -- (busybox grep's BRE does not handle \| reliably).
    local remote_count = tonumber(
        (util.exec("/usr/sbin/vipin-video-domains parse-list /etc/vipin/video-domains.remote 2>/dev/null | wc -l"):gsub("%s+", ""))
    ) or 0

    local local_list = {}
    local f = io.open("/etc/vipin/video-domains.local", "r")
    if f then
        for line in f:lines() do
            local t = line:gsub("^%s+", ""):gsub("%s+$", "")
            if t ~= "" and not t:match("^#") then
                table.insert(local_list, t)
                if #local_list >= 200 then break end
            end
        end
        f:close()
    end

    -- nft list set prints "elements = { ip1, ip2, ... }" and the block may span
    -- multiple lines. Old awk only read the first line — drastically undercounted
    -- or returned 0 whenever the IPs wrapped. Now: extract the whole elements
    -- block with sed, split on commas, count lines that look like an IP.
    local set_count = tonumber(
        (util.exec("nft list set inet fw4 vipin_video 2>/dev/null | sed -n '/elements = {/,/}/p' | tr ',' '\\n' | grep -cE '[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+'"):gsub("%s+", ""))
    ) or 0

    http.prepare_content("application/json")
    http.write(json.encode({
        enabled = (enabled == "1"),
        split_mode = mode,
        remote_count = remote_count,
        local_count = #local_list,
        local_list = local_list,
        set_count = set_count,
        last_refresh = last
    }))
end

function api_video_refresh()
    local http = require("luci.http")
    local json = require("cjson")
    local util = require("luci.util")

    local rc = os.execute("/usr/sbin/vipin-video-domains refresh >/tmp/vipin-video-refresh.log 2>&1")
    http.prepare_content("application/json")
    if rc == 0 or rc == true then
        http.write(json.encode({ success = true }))
    else
        local msg = util.exec("tail -3 /tmp/vipin-video-refresh.log 2>/dev/null")
        http.write(json.encode({ success = false, message = msg or "refresh failed" }))
    end
end

function api_video_toggle()
    local http = require("luci.http")
    local json = require("cjson")

    local enabled = http.formvalue("enabled")
    local target = (enabled == "1" or enabled == "true") and "1" or "0"
    luci.model.uci:set("vipin", "vpn", "video_direct", target)
    luci.model.uci:commit("vipin")
    if target == "1" then
        os.execute("/usr/sbin/vipin-video-domains enable >/dev/null 2>&1")
    else
        os.execute("/usr/sbin/vipin-video-domains disable >/dev/null 2>&1")
    end
    http.prepare_content("application/json")
    http.write(json.encode({ success = true, enabled = (target == "1") }))
end

local function _video_domain_valid(d)
    if not d or d == "" then return false end
    if not d:match("^[a-z0-9%.%-]+$") then return false end
    if d:match("%.%.") or d:match("^%.") or d:match("%.$") then return false end
    if d:match("^%-") or d:match("%-$") then return false end
    if not d:match("%.") then return false end
    return true
end

function api_video_add()
    local http = require("luci.http")
    local json = require("cjson")
    local d = http.formvalue("domain") or ""
    d = string.lower(d):gsub("^%s+", ""):gsub("%s+$", "")
    http.prepare_content("application/json")
    if not _video_domain_valid(d) then
        http.write(json.encode({ success = false, message = "invalid domain format" }))
        return
    end
    local rc = os.execute("/usr/sbin/vipin-video-domains add " .. string.format("%q", d) .. " >/dev/null 2>&1")
    http.write(json.encode({ success = (rc == 0 or rc == true) }))
end

function api_video_remove()
    local http = require("luci.http")
    local json = require("cjson")
    local d = http.formvalue("domain") or ""
    d = string.lower(d):gsub("^%s+", ""):gsub("%s+$", "")
    http.prepare_content("application/json")
    if not _video_domain_valid(d) then
        http.write(json.encode({ success = false, message = "invalid domain format" }))
        return
    end
    local rc = os.execute("/usr/sbin/vipin-video-domains remove " .. string.format("%q", d) .. " >/dev/null 2>&1")
    http.write(json.encode({ success = (rc == 0 or rc == true) }))
end
