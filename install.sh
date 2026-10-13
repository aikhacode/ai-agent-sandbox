#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="${AISANDBOX_INSTALL_DIR:-$HOME/.local/share/aisandbox}"
BIN="$HOME/.local/bin"
mkdir -p "$ROOT/build" "$BIN"

cat > "$ROOT/build/Dockerfile" <<'DOCKERFILE'
FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/agent \
    PATH=/home/agent/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    npm_config_update_notifier=false

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash ca-certificates curl git openssh-client \
      python3 python3-pip python3-venv python3-dev \
      build-essential pkg-config \
      dbus dbus-x11 libsecret-1-0 gnome-keyring \
      less nano vim-tiny jq ripgrep findutils procps \
    && rm -rf /var/lib/apt/lists/*

# CLI packages are installed globally in the image; runtime runs as the host UID.
RUN npm install --global @google/gemini-cli @anthropic-ai/claude-code pnpm \
    && npm cache clean --force

RUN if getent passwd 1000 >/dev/null 2>&1; then userdel -r "$(getent passwd 1000 | cut -d: -f1)" 2>/dev/null || true; fi \
    && if getent group 1000 >/dev/null 2>&1; then groupdel "$(getent group 1000 | cut -d: -f1)" 2>/dev/null || true; fi \
    && groupadd --gid 1000 agent \
    && useradd --uid 1000 --gid 1000 --home-dir /home/agent --shell /bin/bash agent \
    && mkdir -p /workspace /home/agent/.local/bin \
    && cp -rn /etc/skel/. /home/agent/ \
    && chown -R agent:agent /home/agent /workspace

# Install Google's official Antigravity CLI globally.
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash -s -- -d /usr/local/bin \
    && ln -sf /usr/local/bin/agy /usr/local/bin/antigravity

ENV PATH=/home/agent/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin
WORKDIR /workspace
USER agent
CMD ["bash", "--login"]
DOCKERFILE

# Wrapper locates the build context in a stable path, regardless of current directory.
cat > "$BIN/aisandbox" <<'LAUNCHER'
#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE="${AISANDBOX_IMAGE:-local/ai-agent-sandbox:latest}"
STATE="${AISANDBOX_STATE:-${XDG_DATA_HOME:-$HOME/.local/share}/aisandbox}"
MEMORY="${AISANDBOX_MEMORY:-8g}"
CPUS="${AISANDBOX_CPUS:-4}"
PIDS="${AISANDBOX_PIDS:-512}"

usage() {
  cat <<'EOF'
Usage:
  aisandbox [gemini|claude|antigravity|agy|shell|build|status|clean-state] [arguments...]

Examples:
  cd ~/Projects/myapp && aisandbox gemini
  cd ~/Projects/myapp && aisandbox claude
  cd ~/Projects/myapp && aisandbox antigravity
  cd ~/Projects/myapp && aisandbox shell
  aisandbox build

The current directory is mounted at /workspace. Only that project directory and
the dedicated persistent sandbox state directory are mounted into the container.
EOF
}

cmd="${1:-shell}"
if [[ $# -gt 0 ]]; then shift; fi

case "$cmd" in
  -h|--help|help) usage; exit 0 ;;
  build)
    docker build --pull -t "$IMAGE" "${AISANDBOX_DOCKER_CONTEXT:-$STATE/build}"
    exit
    ;;
  status)
    docker image inspect "$IMAGE" --format 'Image: {{.RepoTags}} | ID: {{.Id}}' 2>/dev/null || {
      echo "Image belum dibuat. Jalankan: aisandbox build" >&2; exit 1;
    }
    echo "State: $STATE"
    exit
    ;;
  clean-state)
    echo "Ini akan menghapus login, konfigurasi, cache, dan riwayat CLI di: $STATE"
    read -r -p "Ketik DELETE untuk melanjutkan: " confirm
    [[ "$confirm" == "DELETE" ]] || { echo "Dibatalkan."; exit 1; }
    rm -rf -- "$STATE"
    echo "State dihapus."
    exit
    ;;
  gemini|claude|antigravity|agy|shell) ;;
  *) echo "Perintah tidak dikenal: $cmd" >&2; usage; exit 2 ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker tidak ditemukan. Instal Docker Engine terlebih dahulu." >&2; exit 1
fi
docker image inspect "$IMAGE" >/dev/null 2>&1 || {
  echo "Image sandbox belum dibuat. Jalankan: aisandbox build" >&2; exit 1;
}

# Resolve active project path. Refuse to mount the filesystem root or the home directory.
PROJECT="$(pwd -P)"
if [[ "$PROJECT" == "/" || "$PROJECT" == "$HOME" ]]; then
  echo "Tolak mount '$PROJECT'. Masuk ke direktori proyek terlebih dahulu." >&2
  exit 2
fi
[[ -d "$PROJECT" ]] || { echo "Direktori proyek tidak ditemukan." >&2; exit 2; }

mkdir -p "$STATE/home"
chmod 700 "$STATE" "$STATE/home"
# Docker bind mounts should be writable by the invoking host user.
# Never mount the host home itself; only the dedicated sandbox state directory.
export AISANDBOX_PROJECT="$PROJECT"

agent_cmd=()
case "$cmd" in
  gemini)      agent_cmd=(gemini --yolo "$@") ;;
  claude)      agent_cmd=(claude --dangerously-skip-permissions "$@") ;;
  antigravity|agy) agent_cmd=(agy --dangerously-skip-permissions "$@") ;;
  shell)       agent_cmd=(bash --login "$@") ;;
esac

# The container has no Docker socket, no host PID namespace, no extra capabilities,
# no privilege escalation, a read-only image filesystem, and bounded resources.
# Network is intentionally enabled for model APIs, npm/pip, and downloads.
exec docker run --rm -it \
  --name "aisandbox-$$" \
  --hostname aisandbox \
  --user "$(id -u):$(id -g)" \
  --workdir /workspace \
  --mount "type=bind,src=$PROJECT,dst=/workspace" \
  --mount "type=bind,src=$STATE/home,dst=/home/agent" \
  --network bridge \
  --read-only \
  --tmpfs /tmp:rw,nosuid,nodev,size=1g,mode=1777 \
  --tmpfs /run:rw,nosuid,nodev,size=64m,mode=755 \
  --cap-drop ALL \
  --security-opt no-new-privileges:true \
  --pids-limit "$PIDS" \
  --memory "$MEMORY" \
  --cpus "$CPUS" \
  --init \
  -e HOME=/home/agent \
  -e USER=agent \
  -e LOGNAME=agent \
  -e PATH=/home/agent/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin \
  -e TERM="${TERM:-xterm-256color}" \
  -e COLORTERM="${COLORTERM:-truecolor}" \
  "$IMAGE" \
  "${agent_cmd[@]}"
LAUNCHER

chmod 755 "$BIN/aisandbox"
chmod 644 "$ROOT/build/Dockerfile"
mkdir -p "$ROOT/home"
chmod 700 "$ROOT" "$ROOT/home"

# Add ~/.local/bin to PATH for Bash users if not already present.
if [[ ":${PATH}:" != *":$BIN:"* ]]; then
  profile="$HOME/.bashrc"
  touch "$profile"
  if ! grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$profile"; then
    printf '\n# AI Agent Sandbox\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$profile"
  fi
fi

echo "Files created:"
echo "  Dockerfile: $ROOT/build/Dockerfile"
echo "  Launcher:   $BIN/aisandbox"
echo
echo "Next steps:"
echo "  1) Add ~/.local/bin to PATH (or open a new terminal)"
echo "  2) aisandbox build"
echo "  3) cd into a project directory and run: aisandbox shell"
echo
echo "Note: auto-approve skips agent confirmation prompts. Treat project files and network as untrusted."
