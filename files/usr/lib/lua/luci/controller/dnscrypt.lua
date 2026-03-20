module("luci.controller.dnscrypt", package.seeall)

function index()
    entry({"admin", "network", "dnscrypt"}, cbi("dnscrypt/settings"), "DNSCrypt Proxy", 50)
end
