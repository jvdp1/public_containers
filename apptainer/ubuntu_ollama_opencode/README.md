# OpenCode + Ollama Apptainer SIF (Ubuntu 24.04 / NVIDIA A100)

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Build](#build)
3. [Run — Interactive TUI](#run--interactive-tui)
4. [Run — Background Instance](#run--background-instance)
5. [Stop & Clean Up](#stop--clean-up)
6. [Managing Models](#managing-models)
7. [Environment Variables](#environment-variables)
8. [Bind Mounts (Persistent Storage)](#bind-mounts-persistent-storage)
9. [Logs & Debugging](#logs--debugging)
10. [Updating](#updating)
11. [Container Metadata](#container-metadata)
12. [Recommended Models for A100](#recommended-models-for-a100)
13. [HPC / Slurm Integration](#hpc--slurm-integration)

---

## Prerequisites

### 1. Apptainer installed

```bash
apptainer --version   # must be >= 1.1
```

If not installed, follow the [official guide](https://apptainer.org/docs/admin/main/installation.html).

### 2. NVIDIA driver on the host

```bash
nvidia-smi   # must show the A100
```

No CUDA toolkit installation is required inside the container — Ollama ships its own CUDA runtime, and Apptainer forwards the host driver with `--nv`.

### 3. Unprivileged builds

Apptainer builds from this def file run **without root or fakeroot**. Just execute `apptainer build` as a regular user.

---

## Build

```bash
apptainer build opencode-ollama.sif opencode-ollama.def
```
Force a clean rebuild (ignore cached layers):
```bash
apptainer build --force opencode-ollama.sif opencode-ollama.def
```

Show the built-in help text:

```bash
apptainer run-help opencode-ollama.sif
```

### entrypoint.sh

The `%files` directive in `opencode-ollama.def` bundles `entrypoint.sh` into the image at `/opt/opencode/entrypoint.sh`. This script is the `%runscript` — it runs when you execute `apptainer run` to launch OpenCode via `ollama launch opencode`.

---

## Run — Interactive TUI

This is the primary use case: launch OpenCode with Ollama running in the background.

### Basic

```bash
apptainer run --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif
```

### Pull a model automatically before launching OpenCode

```bash
OLLAMA_MODEL=qwen2.5-coder:32b \
apptainer run --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif
```

> OpenCode is launched via `ollama launch opencode`, which auto-configures
> the Ollama provider without requiring a manual `opencode.json`.
> Any existing `~/.config/opencode/opencode.json` is still respected and
> deep-merged by OpenCode on startup.

### Open a shell instead of OpenCode

```bash
apptainer run --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif bash
```

### Run a single command

```bash
apptainer exec --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif opencode --help
```

---

## Run — Background Instance

Use `apptainer instance` when you want Ollama running persistently in the background (e.g. on a login node or in a job) and attach OpenCode separately.

### Start the instance (Ollama daemon)

```bash
apptainer instance start --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif ollama-svc
```

The `%startscript` section in the def file starts `ollama serve` and waits for the API (up to 60s by default). Connect with:

```bash
apptainer exec instance://ollama-svc ollama launch opencode
```

### Check the instance is running

```bash
apptainer instance list
```

### Pull a model into the running instance

```bash
apptainer exec instance://ollama-svc ollama pull qwen2.5-coder:32b
```

### Launch OpenCode against the running instance

```bash
apptainer exec --nv instance://ollama-svc opencode
```

### Query the Ollama API from the host

```bash
curl http://localhost:11434/api/tags
```

### Stop the instance

```bash
apptainer instance stop ollama-svc
```

### Stop all instances

```bash
apptainer instance stop --all
```

---

## Stop & Clean Up

### Stop a background instance

```bash
apptainer instance stop ollama-svc
```

### Remove the SIF image

```bash
rm opencode-ollama.sif
```

### Remove downloaded models (host-side)

```bash
rm -rf "$OPENCODE_HOME/.ollama"
```

### Remove OpenCode sessions and auth tokens (host-side)

```bash
rm -rf "$OPENCODE_HOME/.local/share/opencode"
```

### Remove OpenCode config (host-side)

```bash
rm -rf "$OPENCODE_HOME/.config/opencode"
```

---

## Managing Models

All `ollama` commands run inside the container but operate on `$OPENCODE_HOME/.ollama` (mounted at `/root/.ollama`), so models persist between runs.

### Against a running instance

```bash
# List downloaded models
apptainer exec instance://ollama-svc ollama list

# Pull a model
apptainer exec instance://ollama-svc ollama pull qwen2.5-coder:32b

# Pull a quantized variant (less VRAM)
apptainer exec instance://ollama-svc ollama pull qwen2.5-coder:32b-instruct-q4_K_M

# Remove a model
apptainer exec instance://ollama-svc ollama rm qwen2.5-coder:32b

# Show model details
apptainer exec instance://ollama-svc ollama show qwen2.5-coder:32b

# Chat with a model directly (bypasses OpenCode)
apptainer exec --nv instance://ollama-svc ollama run qwen2.5-coder:32b
```

### Without a running instance (one-shot)

```bash
apptainer exec --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif ollama pull qwen2.5-coder:32b
```

---

## Environment Variables

Set these **before** the `apptainer run/exec` command or export them in your shell.

> **Note:** Variables defined in the `%environment` section of the def file are set inside the container and **do not** propagate to or from the host shell. To override them, set the variable on the `apptainer run/exec` command line before `--bind` flags.

| Variable | Container Default | Description |
|---|---|---|
| `OLLAMA_MODEL` | _(none)_ | Model to pull automatically on startup |
| `OLLAMA_HOST` | `127.0.0.1:11434` | Ollama API listen address |
| `OLLAMA_NUM_PARALLEL` | `4` | Max concurrent inference requests |
| `OLLAMA_MAX_LOADED_MODELS` | `2` | Max models held in GPU VRAM simultaneously |
| `OLLAMA_KEEP_ALIVE` | `5m` | How long to keep a model loaded after last request |
| `OLLAMA_MODELS` | `/root/.ollama/models` | Directory for Ollama model weights |
| `NVIDIA_VISIBLE_DEVICES` | `all` | Override GPU selection (e.g. `0`, `0,1`) |
| `WAIT_TIMEOUT` | `60` | Seconds to wait for Ollama during instance start |
| `LANGUAGE` | `en_US:en` | Locale (container-only, not exposed for override) |
| `LC_ALL` | `en_US.UTF-8` | Locale setting (container-only) |
| `NVIDIA_DRIVER_CAPABILITIES` | `compute,utility` | NVIDIA driver capabilities (container-only) |

Example — override multiple variables:

```bash
export OLLAMA_MODEL=qwen2.5-coder:32b
export OLLAMA_NUM_PARALLEL=8
export OLLAMA_KEEP_ALIVE=30m

apptainer run --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif
```

---

## Container Metadata

The SIF image includes OCI-compliant metadata. View it with:

```bash
apptainer inspect --labels opencode-ollama.sif
```

| Label | Value |
|---|---|
| `org.opencontainers.image.title` | `OpenCode + Ollama` |
| `org.opencontainers.image.description` | `OpenCode TUI with local Ollama inference on NVIDIA A100` |
| `org.opencontainers.image.base` | `ubuntu:24.04` |

---

## Bind Mounts (Persistent Storage)

Apptainer containers are read-only by default. All state must be stored on bind-mounted host directories.

| Host path | Container path | Contents |
|---|---|---|
| `$OPENCODE_HOME` (any dir) | `/root` | All container home data (`~/.ollama`, `~/.local/share/opencode`, `~/.config/opencode`) |
| _(any project dir)_ | `/workspace` | Your source code |

The example `root-home` directory on the host is mounted as `/root` inside the container, matching the `$HOME` variable set in the def file's `%environment` section.

Create the host directories before first run:

```bash
export OPENCODE_HOME="$(pwd)/root-home"
mkdir -p "$OPENCODE_HOME"
```

Back up the entire host-side home directory:

```bash
tar czf opencode_home_backup.tar.gz --exclude='node_modules' -C "$OPENCODE_HOME" .
```

Restore:

```bash
tar xzf opencode_home_backup.tar.gz -C "$OPENCODE_HOME"
```

---

## Logs & Debugging

Logs are written to the host-side bind mount and survive container restarts.

### Ollama logs

```bash
cat "$OPENCODE_HOME/supervisor/ollama.log"
cat "$OPENCODE_HOME/supervisor/ollama_err.log"
```

### Supervisord log

```bash
cat "$OPENCODE_HOME/supervisor/supervisord.log"
```

### Follow logs live

```bash
tail -f "$OPENCODE_HOME/supervisor/ollama.log"
```

### Check GPU usage from the host

```bash
nvidia-smi
nvidia-smi dmon   # live per-GPU stats
```

### Check GPU usage inside a running instance

```bash
apptainer exec instance://ollama-svc nvidia-smi
```

### Check Ollama API health

```bash
# Basic health
curl http://localhost:11434/

# List available models
curl http://localhost:11434/api/tags
```

### Open a shell in a running instance

```bash
apptainer shell instance://ollama-svc
```

### Inspect OpenCode config

```bash
cat "$OPENCODE_HOME/.config/opencode/opencode.json"
```

### Inspect the SIF image contents

```bash
apptainer shell opencode-ollama.sif          # browse the image filesystem
apptainer inspect opencode-ollama.sif        # show labels and metadata
apptainer inspect --runscript opencode-ollama.sif   # show %runscript
apptainer inspect --startscript opencode-ollama.sif  # show %startscript
apptainer inspect --environment opencode-ollama.sif # show %environment
```

---

## Updating

### Rebuild the image (picks up new OpenCode and Ollama versions)

```bash
apptainer build --force opencode-ollama.sif opencode-ollama.def
```

### Update a specific Ollama model

```bash
# Re-pulling fetches the latest version
apptainer exec --nv \
  --bind $(pwd)/root-home:/root \
  --bind $(pwd):/workspace \
  opencode-ollama.sif ollama pull qwen2.5-coder:32b
```

---

## Recommended Models for A100 (80 GB VRAM)

| Model | Pull command | VRAM | Notes |
|---|---|---|---|
| `qwen2.5-coder:7b` | `ollama pull qwen2.5-coder:7b` | ~5 GB | Fast, lightweight |
| `deepseek-coder-v2:16b` | `ollama pull deepseek-coder-v2:16b` | ~10 GB | Strong coding model |
| `qwen2.5-coder:32b` | `ollama pull qwen2.5-coder:32b` | ~20 GB | Recommended default |
| `llama3.1:70b` | `ollama pull llama3.1:70b` | ~40 GB | General purpose |
| `qwen2.5-coder:72b` | `ollama pull qwen2.5-coder:72b` | ~45 GB | Best coding quality |
| `deepseek-r1:70b` | `ollama pull deepseek-r1:70b` | ~40 GB | Reasoning model |

The A100 80 GB can comfortably run a 72B model, or two 32B models simultaneously (`OLLAMA_MAX_LOADED_MODELS=2`).

---

## HPC / Slurm Integration

Apptainer is the standard container runtime on HPC clusters. Example Slurm batch script:

```bash
#!/bin/bash
#SBATCH --job-name=opencode
#SBATCH --partition=gpu
#SBATCH --gres=gpu:a100:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=64G
#SBATCH --time=04:00:00
#SBATCH --output=opencode_%j.log

# Set host-side home directory (used by --bind and $OPENCODE_HOME)
export OPENCODE_HOME="$HOME/opencode-home"

# Ensure host-side home directory exists
mkdir -p "$OPENCODE_HOME"

# Pull model if not already downloaded
apptainer exec --nv \
  --bind "$OPENCODE_HOME":/root \
  --bind "$SCRATCH/myproject":/workspace \
  "$SCRATCH/opencode-ollama.sif" \
  ollama pull qwen2.5-coder:32b

# Start Ollama as a background instance
apptainer instance start --nv \
  --bind "$OPENCODE_HOME":/root \
  --bind "$SCRATCH/myproject":/workspace \
  "$SCRATCH/opencode-ollama.sif" ollama-svc

# Wait for Ollama to be ready
sleep 10

# Launch OpenCode (uses ollama launch opencode per %runscript)
apptainer exec instance://ollama-svc ollama launch opencode

# Clean up
apptainer instance stop ollama-svc
```

Submit the job:

```bash
sbatch opencode_job.sh
```
