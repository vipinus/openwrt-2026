#!/bin/sh
# One-shot: add libustream-openssl + libopenssl-conf + ca-bundle to all configs.
# These are required for uclient-fetch (wget symlink) to do HTTPS.
set -eu
cd "$(dirname "$0")/../configs"
for f in *.config; do
    for pkg in libustream-openssl libopenssl-conf ca-bundle; do
        grep -q "^CONFIG_PACKAGE_${pkg}=y$" "$f" && continue
        echo "CONFIG_PACKAGE_${pkg}=y" >> "$f"
    done
done
echo "Patched $(ls *.config | wc -l) configs"
