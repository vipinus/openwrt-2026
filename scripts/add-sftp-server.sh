#!/bin/sh
# One-shot: add openssh-sftp-server to all configs for reliable scp/sftp.
# Dropbear ships with scp compat but not sftp-server; `scp` on modern clients
# uses SFTP protocol and fails without this package.
set -eu
cd "$(dirname "$0")/../configs"
n=0
for f in *.config; do
    grep -q '^CONFIG_PACKAGE_openssh-sftp-server=y$' "$f" && continue
    echo 'CONFIG_PACKAGE_openssh-sftp-server=y' >> "$f"
    n=$((n + 1))
done
echo "Added openssh-sftp-server to $n configs"
