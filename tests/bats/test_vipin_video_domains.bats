#!/usr/bin/env bats
# Unit tests for vipin-video-domains
# Run: bats tests/bats/test_vipin_video_domains.bats

SCRIPT="${BATS_TEST_DIRNAME}/../../files/usr/sbin/vipin-video-domains"
FIX="${BATS_TEST_DIRNAME}/fixtures"

setup() {
    export VIPIN_VIDEO_ROOT="$(mktemp -d)"
    export VIPIN_VIDEO_MOCK=1
    mkdir -p "${VIPIN_VIDEO_ROOT}/etc/vipin"
    mkdir -p "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d"
    mkdir -p "${VIPIN_VIDEO_ROOT}/var/lock"
    mkdir -p "${VIPIN_VIDEO_ROOT}/var/log"
}

teardown() {
    rm -rf "$VIPIN_VIDEO_ROOT"
}

@test "script exists and is executable" {
    [ -x "$SCRIPT" ]
}

@test "invoked without args prints usage and exits 2" {
    run "$SCRIPT"
    [ "$status" -eq 2 ]
    [[ "$output" == *"Usage:"* ]]
}
