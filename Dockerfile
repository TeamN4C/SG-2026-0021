FROM ubuntu:24.04 AS builder

ARG DEBIAN_FRONTEND=noninteractive
ARG LLAMA_CPP_REPOSITORY=https://github.com/ggml-org/llama.cpp.git
ARG VULN_REF=b7938
ARG VULN_COMMIT=e0c93af2a03f5c53d052dfaefd86c06ed3784646
RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates cmake g++ git make \
    && rm -rf /var/lib/apt/lists/*

RUN git clone \
        --branch "${VULN_REF}" \
        --depth 1 \
        --filter=blob:none \
        "${LLAMA_CPP_REPOSITORY}" /src \
    && test "$(git -C /src rev-parse HEAD)" = "${VULN_COMMIT}" \
    && git -C /src checkout --detach "${VULN_COMMIT}"

WORKDIR /src
RUN cmake -S . -B build \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DGGML_NATIVE=OFF \
        -DGGML_RPC=ON \
        -DLLAMA_ALL_WARNINGS=OFF \
        -DLLAMA_BUILD_EXAMPLES=OFF \
        -DLLAMA_BUILD_SERVER=OFF \
        -DLLAMA_BUILD_TESTS=OFF \
        -DLLAMA_BUILD_TOOLS=ON \
        -DLLAMA_BUILD_COMMIT="${VULN_COMMIT}" \
    && cmake --build build --target rpc-server -j "$(nproc)"

FROM ubuntu:24.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends bash libgomp1 \
    && rm -rf /var/lib/apt/lists/*
COPY --from=builder /src/build/bin/rpc-server /usr/local/bin/rpc-server
EXPOSE 50052
ENTRYPOINT ["/usr/local/bin/rpc-server"]
CMD ["--host", "0.0.0.0", "--port", "50052", "--threads", "1", "--device", "CPU"]
