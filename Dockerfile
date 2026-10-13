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
