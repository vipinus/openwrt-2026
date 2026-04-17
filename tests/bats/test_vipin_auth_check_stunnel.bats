#!/usr/bin/env bats

@test "is_stack_running returns 0 when both stunnel and tun2socks present" {
    export VIPIN_AUTH_CHECK_MOCK=1
    export VIPIN_AUTH_CHECK_STUNNEL_RUNNING=1
    export VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING=1
    run /bin/sh -c '. files/usr/sbin/vipin-auth-check; is_stack_running'
    [ "$status" -eq 0 ]
}

@test "is_stack_running returns 1 when stunnel missing" {
    export VIPIN_AUTH_CHECK_MOCK=1
    export VIPIN_AUTH_CHECK_STUNNEL_RUNNING=0
    export VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING=1
    run /bin/sh -c '. files/usr/sbin/vipin-auth-check; is_stack_running'
    [ "$status" -eq 1 ]
}

@test "is_stack_running returns 1 when tun2socks missing" {
    export VIPIN_AUTH_CHECK_MOCK=1
    export VIPIN_AUTH_CHECK_STUNNEL_RUNNING=1
    export VIPIN_AUTH_CHECK_TUN2SOCKS_RUNNING=0
    run /bin/sh -c '. files/usr/sbin/vipin-auth-check; is_stack_running'
    [ "$status" -eq 1 ]
}
