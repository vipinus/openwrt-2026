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
