#!/usr/bin/env bash
# =============================================================================
# entrypoint.sh
# `ollama launch opencode` starts ollama serve internally, configures the
# Ollama provider for OpenCode via OPENCODE_CONFIG_CONTENT, and execs opencode.
# HOME is set to /root so Ollama never touches the real HPC home directory.
# =============================================================================
set -e

# Ensure Ollama uses the bind-mounted directory, never the real $HOME
export OLLAMA_MODELS=/root/.ollama/models
export HOME=/root

# ---------------------------------------------------------------------------
# Optional: pull a model before launching
#   OLLAMA_MODEL=qwen2.5-coder:32b apptainer run --nv ... opencode-ollama.sif
# ---------------------------------------------------------------------------
if [ -n "${OLLAMA_MODEL}" ]; then
    echo "[entrypoint] Starting Ollama to pull model: ${OLLAMA_MODEL}..."
    OLLAMA_HOST=127.0.0.1:11434 ollama serve &
    OLLAMA_PID=$!

    until curl -sf http://127.0.0.1:11434/ > /dev/null 2>&1; do sleep 1; done

    ollama pull "${OLLAMA_MODEL}"

    kill $OLLAMA_PID
    wait $OLLAMA_PID 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# Print GPU info (informational)
# ---------------------------------------------------------------------------
if command -v nvidia-smi > /dev/null 2>&1; then
    echo "[entrypoint] GPU info:"
    nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader
fi

# ---------------------------------------------------------------------------
# Launch — ollama launch opencode starts its own ollama serve internally,
# configures the Ollama provider, and execs opencode.
# If an explicit command is passed, run that instead.
# ---------------------------------------------------------------------------
if [ "$#" -gt 0 ]; then
    exec "$@"
else
    exec ollama launch opencode
fi
