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

@test "validate-domain: accepts valid domains" {
    run "$SCRIPT" validate-domain "foo.example.com"
    [ "$status" -eq 0 ]
    run "$SCRIPT" validate-domain "a.b"
    [ "$status" -eq 0 ]
    run "$SCRIPT" validate-domain "x-y.example.net"
    [ "$status" -eq 0 ]
}

@test "validate-domain: rejects double-dot, leading-dot, trailing-dot" {
    run "$SCRIPT" validate-domain "foo..bar"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain ".foo.bar"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "foo.bar."
    [ "$status" -ne 0 ]
}

@test "validate-domain: rejects leading/trailing dash, bare hostname, empty, illegal chars" {
    run "$SCRIPT" validate-domain "-foo.bar"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "foo.bar-"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "nodot"
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain ""
    [ "$status" -ne 0 ]
    run "$SCRIPT" validate-domain "foo!bar.com"
    [ "$status" -ne 0 ]
}

@test "merge: combines remote + local, deduped" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    cp "$FIX/domains-local-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [[ "$output" == *"netflix.ca"* ]]
    [[ "$output" == *"my.custom-cdn.example.com"* ]]
    local n
    n=$(echo "$output" | grep -cx "hdslb.com")
    [ "$n" = "1" ]
}

@test "merge: works with only remote present" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [[ "$output" == *"netflix.ca"* ]]
}

@test "merge: works with only local present" {
    cp "$FIX/domains-local-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [[ "$output" == *"my.custom-cdn.example.com"* ]]
}

@test "merge: empty when no files" {
    run "$SCRIPT" merge
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "render-dnsmasq: produces nftset directives" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" render-dnsmasq
    [ "$status" -eq 0 ]
    [[ "$output" == *"nftset=/netflix.ca/4#inet#fw4#vipin_video"* ]]
    [[ "$output" == *"nftset=/bilivideo.com/4#inet#fw4#vipin_video"* ]]
    [[ "$output" == *"# Auto-generated"* ]]
}

@test "render-dnsmasq: skips blank/invalid domains from merge output" {
    printf "\nnetflix.ca\n\n" > "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" render-dnsmasq
    [ "$status" -eq 0 ]
    local n
    n=$(echo "$output" | grep -c "^nftset=")
    [ "$n" = "1" ]
}

@test "enable: writes dnsmasq include with merged domains" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" enable
    [ "$status" -eq 0 ]
    local conf="${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf"
    [ -f "$conf" ]
    grep -q "nftset=/netflix.ca/4#inet#fw4#vipin_video" "$conf"
}

@test "enable: writes atomically via .new then rename" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    run "$SCRIPT" enable
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf.new" ]
}

@test "disable: removes dnsmasq include" {
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    "$SCRIPT" enable
    run "$SCRIPT" disable
    [ "$status" -eq 0 ]
    [ ! -f "${VIPIN_VIDEO_ROOT}/etc/dnsmasq.d/vipin-video.conf" ]
}

@test "add: appends valid domain to local file" {
    run "$SCRIPT" add "foo.example.com"
    [ "$status" -eq 0 ]
    grep -qx "foo.example.com" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
}

@test "add: rejects invalid domain" {
    run "$SCRIPT" add "not_a_domain"
    [ "$status" -ne 0 ]
}

@test "add: idempotent — duplicate not appended" {
    "$SCRIPT" add "foo.example.com"
    "$SCRIPT" add "foo.example.com"
    local n
    n=$(grep -cx "foo.example.com" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local")
    [ "$n" = "1" ]
}

@test "remove: deletes existing domain" {
    "$SCRIPT" add "foo.example.com"
    run "$SCRIPT" remove "foo.example.com"
    [ "$status" -eq 0 ]
    ! grep -qx "foo.example.com" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
}

@test "remove: idempotent when domain absent" {
    touch "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.local"
    run "$SCRIPT" remove "not.present.example"
    [ "$status" -eq 0 ]
}

@test "add: releases lock on success" {
    "$SCRIPT" add "foo.example.com"
    [ ! -f "${VIPIN_VIDEO_ROOT}/var/lock/vipin-video.lock" ]
}

@test "refresh: successful curl updates remote and last_refresh" {
    export VIPIN_VIDEO_MOCK_CURL_OK=1
    cp "$FIX/domains-remote-sample.txt" "${VIPIN_VIDEO_ROOT}/mock-fetch.txt"
    export VIPIN_VIDEO_MOCK_CURL_PAYLOAD="${VIPIN_VIDEO_ROOT}/mock-fetch.txt"

    run "$SCRIPT" refresh
    [ "$status" -eq 0 ]
    [ -f "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote" ]
    grep -q "netflix.ca" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
}

@test "refresh: failed curl preserves old remote" {
    echo "OLD.CONTENT" > "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    export VIPIN_VIDEO_MOCK_CURL_OK=0

    run "$SCRIPT" refresh
    [ "$status" -ne 0 ]
    grep -q "OLD.CONTENT" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
}

@test "refresh: empty payload is treated as failure" {
    echo "OLD.CONTENT" > "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
    export VIPIN_VIDEO_MOCK_CURL_OK=1
    echo -n "" > "${VIPIN_VIDEO_ROOT}/empty.txt"
    export VIPIN_VIDEO_MOCK_CURL_PAYLOAD="${VIPIN_VIDEO_ROOT}/empty.txt"

    run "$SCRIPT" refresh
    [ "$status" -ne 0 ]
    grep -q "OLD.CONTENT" "${VIPIN_VIDEO_ROOT}/etc/vipin/video-domains.remote"
}
