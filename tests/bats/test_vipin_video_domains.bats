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

@test "parse-list: strips comments, blanks, whitespace, lowercases" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/in.txt"
    run "$SCRIPT" parse-list "${VIPIN_VIDEO_ROOT}/in.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"netflix.ca"* ]]
    [[ "$output" == *"bilivideo.com"* ]]
    [[ "$output" == *"apdcdn.tc.qq.com"* ]]
    [[ "$output" != *"#"* ]]
    [[ "$output" != *"comment line"* ]]
}

@test "parse-list: returns empty for missing file" {
    run "$SCRIPT" parse-list "${VIPIN_VIDEO_ROOT}/nope.txt"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "parse-list: handles uppercase input by lowercasing" {
    echo "FOO.BAR.com" > "${VIPIN_VIDEO_ROOT}/up.txt"
    run "$SCRIPT" parse-list "${VIPIN_VIDEO_ROOT}/up.txt"
    [ "$status" -eq 0 ]
    [[ "$output" == "foo.bar.com" ]]
}
