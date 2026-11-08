#!/usr/bin/env bash
# Check authentication and permanent firewall configuration in an isolated Fedora 45 container.
set -Eeuo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Disable container labeling, not host SELinux, to read mounts without relabeling the checkout.
podman run --rm -i --pull=never --network=none --security-opt label=disable \
    --entrypoint /bin/bash \
    -v "$repo_root/build_files/system/configure-security-hardening:/review/script:ro" \
    -v "$repo_root/system_files/overrides/etc/firewalld/zones/FedoraWorkstation.xml:/etc/firewalld/zones/FedoraWorkstation.xml:ro" \
    -v "$repo_root/system_files/overrides/etc/audit/rules.d:/review/rules:ro" \
    ghcr.io/ublue-os/base-main:45 -Eeuo pipefail -s <<'BASH'
rpm -q fedora-release authselect firewalld audit audit-rules
# Run only the authentication/firewall block, not unrelated image installation steps.
sed -n '/^authselect check/,/^# secureblue-derived/{ /^# secureblue-derived/d; p; }' \
    /review/script > /tmp/check
test -s /tmp/check
bash -Eeuo pipefail /tmp/check
bash -Eeuo pipefail /tmp/check
test "$(firewall-offline-cmd --get-default-zone)" = FedoraWorkstation
test "$(firewall-offline-cmd --zone=FedoraWorkstation --list-services)" = dhcpv6-client
test "$(firewall-offline-cmd --zone=FedoraWorkstation --list-ports)" = 47/tcp
test "$(firewall-offline-cmd --zone=FedoraWorkstation --get-target)" = default
test "$(systemctl is-enabled firewalld.service)" = enabled

authselect() {
    if [[ "$1" == current ]]; then
        echo sssd
    else
        command authselect "$@"
    fi
}
export -f authselect
if bash -Eeuo pipefail /tmp/check; then
    echo 'FAIL: accepted unexpected authentication profile' >&2
    exit 1
fi
unset -f authselect
authselect opt-out
if bash -Eeuo pipefail /tmp/check; then
    echo 'FAIL: accepted unmanaged PAM configuration' >&2
    exit 1
fi

for abi in b32 b64; do
    arch=i386
    [[ "$abi" == b32 ]] || arch=x86_64
    mapfile -t syscalls < <(grep -h "arch=$abi" /review/rules/*.rules |
        sed -n 's/.* -S \([^ ]*\).*/\1/p' | tr , '\n' | sort -u)
    ((${#syscalls[@]} > 0))
    for syscall in "${syscalls[@]}"; do
        ausyscall "$arch" "$syscall" --exact >/dev/null
    done
done
echo 'PASS: Fedora 45 authentication, firewall defaults, idempotency, rejection checks, and audit syscall names'
BASH
