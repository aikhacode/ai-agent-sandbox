FROM node:22-bookworm

ENV DEBIAN_FRONTEND=noninteractive \
    HOME=/home/agent \
    PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin \
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

RUN groupadd --gid 1000 agent \
    && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash agent \
    && mkdir -p /workspace /home/agent/.local/bin \
    && chown -R agent:agent /home/agent /workspace

# Install Google's official Antigravity CLI as the non-root image user.
RUN runuser -u agent -- env HOME=/home/agent PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin \
      bash -lc 'curl -fsSL https://antigravity.google/cli/install.sh | bash'

ENV PATH=/home/agent/.local/bin:/usr/local/bin:/usr/bin:/bin
WORKDIR /workspace
USER agent
CMD ["bash", "--login"]
