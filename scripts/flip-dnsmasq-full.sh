#!/bin/sh
# One-shot: replace CONFIG_PACKAGE_dnsmasq=y with CONFIG_PACKAGE_dnsmasq-full=y
# in every configs/*.config file. Idempotent.

set -eu
cd "$(dirname "$0")/../configs"

changed=0
for f in *.config; do
    if grep -q '^CONFIG_PACKAGE_dnsmasq=y$' "$f"; then
        sed -i 's/^CONFIG_PACKAGE_dnsmasq=y$/CONFIG_PACKAGE_dnsmasq-full=y/' "$f"
        changed=$((changed + 1))
    fi
done
echo "Flipped: $changed files"
