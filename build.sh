#!/usr/bin/env bash
set -euo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly LLAMA_CPP_REPOSITORY="${LLAMA_CPP_REPOSITORY:-https://github.com/ggml-org/llama.cpp.git}"
readonly VULN_REF="${VULN_REF:-b7938}"
readonly VULN_COMMIT="e0c93af2a03f5c53d052dfaefd86c06ed3784646"
readonly IMAGE_NAME="${IMAGE_NAME:-llama-cve-2026-34159-exploit}"

if ! command -v docker >/dev/null 2>&1; then
    echo "error: required command not found: docker" >&2
    exit 1
fi

echo "[*] building non-ASan exploit target ${IMAGE_NAME} from vulnerable release ${VULN_REF} (${VULN_COMMIT})"
echo "[*] cloning ${LLAMA_CPP_REPOSITORY} at ${VULN_REF} inside the Docker builder"
docker build \
    --build-arg "LLAMA_CPP_REPOSITORY=${LLAMA_CPP_REPOSITORY}" \
    --build-arg "VULN_REF=${VULN_REF}" \
    --build-arg "VULN_COMMIT=${VULN_COMMIT}" \
    --file "${SCRIPT_DIR}/Dockerfile" \
    --tag "${IMAGE_NAME}" \
    "${SCRIPT_DIR}"
