# AI Agent Sandbox (Docker)

Linux Mint / Ubuntu Docker sandbox for Gemini CLI, Claude Code CLI, and Google's official Antigravity CLI (`agy`), with Node.js/npm and Python/pip/venv.

## Install

1. Install Docker Engine and ensure your user can run `docker`.
2. Run the provided `install.sh`.
3. Open a new terminal, or run `export PATH="$HOME/.local/bin:$PATH"`.
4. Build the image: `aisandbox build`.
5. In a project directory, run `aisandbox shell`.

## Use

- `aisandbox gemini` — Gemini CLI with `--yolo`
- `aisandbox claude` — Claude Code with `--dangerously-skip-permissions`
- `aisandbox antigravity` or `aisandbox agy` — Antigravity CLI with `--dangerously-skip-permissions`
- `aisandbox shell` — Bash shell
- `aisandbox build` — build/update image
- `aisandbox status` — image status
- `aisandbox clean-state` — remove saved login/config/history after typed confirmation

The current working directory is mounted at `/workspace`; the dedicated persistent state directory is mounted at `/home/agent`. No other host project directories, host home directory, or Docker socket are mounted.

## Authentication

Run each CLI in its own sandbox session and follow its interactive login prompts. State persists at `~/.local/share/aisandbox/home`. For browser-based login, follow the URL/device flow printed by the CLI if available. Do not copy your entire host `~/.config`, `~/.ssh`, cloud credentials, or browser profile into the container.

Antigravity uses a system keyring when available, then may fall back to Google sign-in. Container keyring behavior can differ from a desktop session; if login cannot persist, use the CLI's documented supported authentication method or configure a supported API-key provider rather than mounting the host keyring blindly.

## Security notes

- This configuration deliberately enables network access.
- Auto-approve is convenience, not a security boundary. Agents can execute code, modify/delete everything in `/workspace`, read their own persisted credentials, and send data over the network.
- Do not run this against projects containing secrets you would not trust the agent to read. Consider a clean Git branch/working tree and backups.
- Container root filesystem is read-only; `/tmp` and `/run` are temporary writable mounts; Linux capabilities are dropped; privilege escalation is disabled; memory/CPU/processes are bounded.
- Files in `/workspace` are writable and changes are reflected on the host.
- Do not mount `/var/run/docker.sock`; doing so would effectively grant control over the host.
- The sandbox does not provide a separate network egress allowlist. Internet is open as requested.
- CLI auto-approval flags can change between releases. Verify the CLI's current `--help` if an update changes behavior.

## Node and Python

Inside `aisandbox shell`:
- `node --version`
- `npm --version`
- `pnpm --version` (if unavailable, enable it with `corepack enable` if permissions allow; otherwise use `npm install -g pnpm` in a rebuilt image)
- `python3 --version`
- `python3 -m venv .venv`
- `. .venv/bin/activate`
- `python -m pip install -r requirements.txt`

For project packages that need native compilation, `build-essential`, `python3-dev`, and `pkg-config` are included.
