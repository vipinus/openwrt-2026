#!/usr/bin/env bats

@test "resolve_connect_server: non-CN router + cn.fanq.in -> un.fanq.in" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "un.fanq.in" ]
}

@test "resolve_connect_server: CN router + cn.fanq.in -> cn.fanq.in" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=cn
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "cn.fanq.in" ]
}

@test "resolve_connect_server: non-CN router + jp.fanq.in -> jp.fanq.in" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=jp.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "jp.fanq.in" ]
}

@test "resolve_connect_server: CN router + jp.fanq.in -> jp.fanq.in" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=cn
    export VIPIN_VPN_UCI_SERVER=jp.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; resolve_connect_server'
    [ "$status" -eq 0 ]
    [ "$output" = "jp.fanq.in" ]
}

@test "fetch_auth_params: status=ok writes params file and returns 0" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_API_RESPONSE='{"status":"ok","session_expires":1700000000,"tunnel":{"port":22,"ca_cert":"CERT"},"dns":{"stunnel_host":"cn2.fanq.in","stunnel_port":994},"split":{"default_mode":"forward"}}'
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; fetch_auth_params user pass AA:BB'
    [ "$status" -eq 0 ]
    [ -f "$VIPIN_CONFIG_DIR/auth-params.json" ]
    grep -q '"status":"ok"' "$VIPIN_CONFIG_DIR/auth-params.json"
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "fetch_auth_params: status=expired returns 1" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_API_RESPONSE='{"status":"expired","message":"trial ended"}'
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; fetch_auth_params user pass AA:BB'
    [ "$status" -eq 1 ]
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "fetch_auth_params: empty response (network) returns 2" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_API_RESPONSE=''
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; fetch_auth_params user pass AA:BB'
    [ "$status" -eq 2 ]
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "extract_ca_cert: writes CA from auth-params.json" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    cat > "$VIPIN_CONFIG_DIR/auth-params.json" <<EOF
{"status":"ok","tunnel":{"port":22,"ca_cert":"-----BEGIN CERTIFICATE-----\nMIIBXX\n-----END CERTIFICATE-----\n"}}
EOF
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; extract_ca_cert'
    [ "$status" -eq 0 ]
    [ -f "$VIPIN_CONFIG_DIR/stunnel-ca.pem" ]
    grep -q 'BEGIN CERTIFICATE' "$VIPIN_CONFIG_DIR/stunnel-ca.pem"
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "render_stunnel_conf: uses port from auth + connect_server from resolve" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    export VIPIN_CONFIG_DIR="$BATS_TMPDIR/vipin-test-$$"
    mkdir -p "$VIPIN_CONFIG_DIR"
    cat > "$VIPIN_CONFIG_DIR/auth-params.json" <<EOF
{"status":"ok","tunnel":{"port":22,"ca_cert":"CERT"}}
EOF
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; render_stunnel_conf'
    [ "$status" -eq 0 ]
    [ -f "$VIPIN_CONFIG_DIR/stunnel-client.conf" ]
    grep -q 'connect = un.fanq.in:22' "$VIPIN_CONFIG_DIR/stunnel-client.conf"
    grep -q 'accept = 127.0.0.1:1080' "$VIPIN_CONFIG_DIR/stunnel-client.conf"
    grep -q 'client = yes' "$VIPIN_CONFIG_DIR/stunnel-client.conf"
    rm -rf "$VIPIN_CONFIG_DIR"
}

@test "configure_dns: overseas router + cn server, no dns.txt -> WAN DNS" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    export VIPIN_VPN_WAN_DNS=192.0.2.53
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "192.0.2.53" ]
}

@test "configure_dns: cn router + un.fanq.in:3333 reachable -> 47.242.64.28#3333" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=cn
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    export VIPIN_VPN_WAN_DNS=192.0.2.53
    export VIPIN_VPN_UN_DNS_OK=1
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "47.242.64.28#3333" ]
}

@test "configure_dns: cn router + un:3333 unreachable -> WAN DNS fallback" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=cn
    export VIPIN_VPN_UCI_SERVER=cn.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    export VIPIN_VPN_WAN_DNS=192.0.2.53
    export VIPIN_VPN_UN_DNS_OK=0
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "192.0.2.53" ]
}

@test "configure_dns: overseas router + jp server -> WAN DNS" {
    export VIPIN_VPN_MOCK=1
    export VIPIN_VPN_ROUTER_COUNTRY=ca
    export VIPIN_VPN_UCI_SERVER=jp.fanq.in
    export VIPIN_VPN_BASE_DOMAIN=fanq.in
    export VIPIN_VPN_WAN_DNS=192.0.2.53
    run /bin/sh -c '. files/etc/init.d/vipin-vpn; configure_dns'
    [ "$status" -eq 0 ]
    [ "$output" = "192.0.2.53" ]
}
