FROM ollama/ollama:latest

ARG OLLAMA_MODEL=qwen2.5:3b
ENV OLLAMA_MODEL=${OLLAMA_MODEL}

RUN set -eu; \
    ollama serve >/tmp/ollama.log 2>&1 & \
    server_pid=$!; \
    trap 'kill "$server_pid" 2>/dev/null || true' EXIT; \
    until ollama list >/dev/null 2>&1; do sleep 2; done; \
    ollama pull "$OLLAMA_MODEL"
