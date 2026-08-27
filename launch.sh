#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE_NAME="${IMAGE_NAME:-llama-cve-2026-34159-poc}"
readonly HOST_PORT="${HOST_PORT:-50052}"
readonly CONTAINER_NAME="${CONTAINER_NAME:-llama-cve-2026-34159-poc-asan}"

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "error: image not found: ${IMAGE_NAME} (run ./build.sh first)" >&2
    exit 1
fi
if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "error: container already exists: ${CONTAINER_NAME}" >&2
    echo "remove it explicitly before launching a new run" >&2
    exit 1
fi

echo "[*] starting the ASan-instrumented vulnerable RPC service on 127.0.0.1:${HOST_PORT}"
echo "[*] in another terminal run: python3 poc.py 127.0.0.1 ${HOST_PORT}"
echo "[*] after the crash inspect: docker logs ${CONTAINER_NAME}"
exec docker run \
    --name "${CONTAINER_NAME}" \
    --publish "127.0.0.1:${HOST_PORT}:50052" \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --env GGML_RPC_DEBUG=1 \
    --env ASAN_OPTIONS=abort_on_error=1:halt_on_error=1:detect_leaks=0:print_stacktrace=1:allow_addr2line=1 \
    --read-only \
    --tmpfs /tmp:rw,nosuid,nodev,noexec,size=16m \
    "${IMAGE_NAME}"
