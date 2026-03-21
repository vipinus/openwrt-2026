#!/usr/bin/env python3
import os
import re

CONFIGS_DIR = "/home/ddxs/Dev/router/openwrt-new/configs"
EXCLUDED = {"GLINET-GL-MT300N.config"}

PACKAGES_DISABLE = [
    "CONFIG_PACKAGE_luci=y",
    "CONFIG_PACKAGE_luci-ssl=y",
    "CONFIG_PACKAGE_luci-light=y",
    "CONFIG_PACKAGE_dnsmasq-full=y",
    "CONFIG_PACKAGE_luci-app-dnscrypt-proxy=y",
    "CONFIG_PACKAGE_dnsmasq_full_dhcp=y",
    "CONFIG_PACKAGE_dnsmasq_full_dnssec=y",
    "CONFIG_PACKAGE_procd-ujail=y",
]

OPTIONS_DISABLE = [
    "CONFIG_DEFAULT_procd-ujail=y",
    "CONFIG_AUTOREMOVE=y",
]

PACKAGES_ENABLE = [
    "CONFIG_PACKAGE_luci-base=y",
    "CONFIG_PACKAGE_luci-mod-admin-full=y",
    "CONFIG_PACKAGE_luci-compat=y",
    "CONFIG_PACKAGE_uhttpd=y",
    "CONFIG_PACKAGE_rpcd-mod-luci=y",
    "CONFIG_PACKAGE_openssl-util=y",
    "CONFIG_PACKAGE_curl=y",
    "CONFIG_PACKAGE_ca-bundle=y",
    "CONFIG_PACKAGE_iputils-ping=y",
    "CONFIG_PACKAGE_resolveip=y",
    "CONFIG_PACKAGE_cron=y",
    "CONFIG_PACKAGE_kmod-tun=y",
    "CONFIG_PACKAGE_openconnect=y",
    "CONFIG_PACKAGE_dnscrypt-proxy2=y",
]

ADD_IF_MISSING = [
    "CONFIG_IPV6=y",
    "CONFIG_NFTABLES_IPV6=y",
]


def get_enabled_set(lines):
    enabled = set()
    for line in lines:
        stripped = line.strip()
        if stripped.startswith('#'):
            for pkg in PACKAGES_ENABLE:
                if stripped == f"# {pkg} is not set":
                    enabled.add(f"# {pkg} is not set")
            continue
        for pkg in PACKAGES_ENABLE:
            if stripped == pkg:
                enabled.add(pkg)
        for pkg in ADD_IF_MISSING:
            if stripped == pkg:
                enabled.add(pkg)
        for pkg in PACKAGES_DISABLE + OPTIONS_DISABLE:
            if stripped == pkg:
                enabled.add(pkg)
    return enabled


def fix_config(filepath):
    with open(filepath, 'r') as f:
        lines = f.readlines()

    enabled = get_enabled_set(lines)
    modified = False

    new_lines = []
    for line in lines:
        stripped = line.strip()

        if stripped in PACKAGES_DISABLE:
            base = stripped.replace("=y", "")
            new_lines.append(f"# {base} is not set\n")
            modified = True
        elif stripped in OPTIONS_DISABLE:
            base = stripped.replace("=y", "")
            new_lines.append(f"# {base} is not set\n")
            modified = True
        elif any(stripped.startswith(f"# {pkg} ") or stripped == f"# {pkg}" for pkg in PACKAGES_DISABLE):
            for pkg in PACKAGES_DISABLE:
                if stripped.startswith(f"# {pkg} ") or stripped == f"# {pkg}":
                    base = pkg.replace("=y", "")
                    new_lines.append(f"# {base} is not set\n")
                    modified = True
                    break
            else:
                new_lines.append(line)
        elif any(stripped.startswith(f"# {opt} ") or stripped == f"# {opt}" for opt in OPTIONS_DISABLE):
            for opt in OPTIONS_DISABLE:
                if stripped.startswith(f"# {opt} ") or stripped == f"# {opt}":
                    base = opt.replace("=y", "")
                    new_lines.append(f"# {base} is not set\n")
                    modified = True
                    break
            else:
                new_lines.append(line)
        elif any(stripped == f"# {pkg} is not set" for pkg in PACKAGES_ENABLE):
            pkg_to_enable = stripped[2:]
            pkg_base = pkg_to_enable.replace(" is not set", "=y")
            if f"# {pkg_base} is not set" not in enabled and pkg_base not in enabled:
                new_lines.append(pkg_base + "\n")
                enabled.add(pkg_base)
                modified = True
            else:
                new_lines.append(line)
        else:
            new_lines.append(line)

    for pkg in ADD_IF_MISSING + PACKAGES_ENABLE:
        if pkg not in enabled:
            new_lines.append(pkg + "\n")
            modified = True

    if modified:
        with open(filepath, 'w') as f:
            f.writelines(new_lines)

    return modified


def main():
    configs = sorted([f for f in os.listdir(CONFIGS_DIR)
                      if f.endswith('.config') and f not in EXCLUDED])

    fixed = 0
    for cfg in configs:
        filepath = os.path.join(CONFIGS_DIR, cfg)
        modified = fix_config(filepath)
        if modified:
            print(f"Fixed {cfg}")
            fixed += 1
        else:
            print(f"No changes: {cfg}")

    print(f"\nTotal: {len(configs)} configs processed, {fixed} fixed")


if __name__ == '__main__':
    main()
