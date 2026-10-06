#!/usr/bin/env bash
# halcyon build step — mirror the signing module's trust scope to quay.io.
#
# The bluebuild signing module scopes /etc/containers/policy.json AND a
# registries.d use-sigstore-attachments file to exactly ONE reference (the
# ghcr repo). The quay.io mirror pushed by build.yml has its own manifest
# digest and its own cosign signature (same key), so the enforced rebase
# path (`bootc switch --enforce-container-sigpolicy
# ostree-image-signed:docker://quay.io/...`) needs the same two entries
# for the mirror ref. This cannot be a files overlay: the signing module
# runs AFTER the files stage and rewrites policy.json, so the edit must
# come here, right after signing.
set -euo pipefail

QUAY_REF="quay.io/halcyon-linux/halcyon"
KEY="/etc/pki/containers/halcyon.pub"
POLICY=/etc/containers/policy.json
REG_D=/etc/containers/registries.d/quay-io-halcyon.yaml

echo "::group::quay-signing — mirror the policy scope to quay.io"

if [ ! -f "${POLICY}" ] || [ ! -f "${KEY}" ]; then
  echo "  FAIL  ${POLICY} or ${KEY} missing — did the signing module run?" >&2
  exit 1
fi

jq --arg ref "${QUAY_REF}" --arg key "${KEY}" \
  '.transports.docker |=
    { ($ref): [
        {
            "type": "sigstoreSigned",
            "keyPath": $key,
            "signedIdentity": {"type": "matchRepository"}
        }
    ] } + .' "${POLICY}" > /tmp/POLICY.tmp

mv /tmp/POLICY.tmp "${POLICY}"

cat > "${REG_D}" <<EOF
docker:
  ${QUAY_REF}:
    use-sigstore-attachments: true
EOF

# Gates: the merge must have landed in both files.
jq -e --arg ref "${QUAY_REF}" '.transports.docker[$ref][0].type == "sigstoreSigned"' \
  "${POLICY}" >/dev/null || {
  echo "  FAIL  ${QUAY_REF} not in policy.json after the merge" >&2
  exit 1
}
grep -qF "${QUAY_REF}" "${REG_D}" || {
  echo "  FAIL  ${QUAY_REF} not registered for sigstore attachments" >&2
  exit 1
}
echo "  OK    policy.json + registries.d now trust ${QUAY_REF}"
echo "::endgroup::"
echo "--- quay-signing complete ---"
