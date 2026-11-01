# cc-sandbox-runtime

Docker image for running AI coding agents (claude-code) with unified cloud
infrastructure via [multica](https://github.com/multica-ai/multica), with the
Claude Code native sandbox (bubblewrap + socat + ripgrep) built in.

> Migrated from [agents-with-multica](https://github.com/courage-zen/agents-with-multica)
> (private) — the base image build system and sandbox documentation, first
> release v1.0.0.

## Image

| Image | GHCR |
|---|---|
| cc-sandbox-runtime | `ghcr.io/courage-zen/cc-sandbox-runtime:<tag>` |

Tags follow the pattern `<version>-<arch>` / `latest-<arch>` where `<arch>`
is `amd64` or `arm64`:

```
ghcr.io/courage-zen/cc-sandbox-runtime:1.0.0-arm64
ghcr.io/courage-zen/cc-sandbox-runtime:latest-amd64
```

## Usage

Requires both cc-proxy config (volume mount) and multica config (volume mount):

```sh
docker run -d \
  -v /path/to/cc-proxy-config.yaml:/home/agent/.cc-proxy/config.yaml:ro \
  -v /path/to/multica-config.json:/etc/multica/config.json:ro \
  -e MULTICA_AGENT_RUNTIME_NAME="my-agent" \
  --cap-drop ALL \
  ghcr.io/courage-zen/cc-sandbox-runtime:latest-amd64
```

See `config/run.sh.example` for the full hardened deployment template
(non-privileged, `--cap-drop ALL`, custom seccomp profile).

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `MULTICA_AGENT_RUNTIME_NAME` | No | Display name for this runtime (default: `Docker`) |
| `MULTICA_DAEMON_DEVICE_NAME` | No | Device name for the multica daemon (default: `Docker`) |
| `GIT_TOKEN` | No | Git token; entrypoint writes `~/.git-credentials` then unsets it |
| `GIT_HOST` | No | Git host for the credential line (used with `GIT_TOKEN`) |

The container runs as non-root `agent` (uid 1001). cc-proxy listens on
`127.0.0.1:15721` (unprivileged port), multica daemon connects to the server
configured in the mounted config.

## Sandbox

The image ships the Claude Code native sandbox runtime dependencies
(bubblewrap, socat, ripgrep). Enable the per-command sandbox via
`~/.claude/settings.json` (the `sandbox` block: `enabled`,
`failIfUnavailable`, `network.allowedDomains`, `credentials` deny rules).

## Configuration

### Private release dependencies

`courage-zen/cc-proxy` and `courage-zen/multica-stdio-mcp-proxy` are private.
Local builds download them with the authenticated GitHub CLI before Docker
builds the image:

```sh
gh release download v0.4.1 -R courage-zen/cc-proxy \
  -p cc-proxy-amd64 -O binaries/amd64/cc-proxy
gh release download v0.1.0 -R courage-zen/multica-stdio-mcp-proxy \
  -p multica-stdio-mcp-proxy-linux-amd64 -O binaries/amd64/multica-stdio-mcp-proxy
```

CI uses the `CC_PROXY_TOKEN` repository secret — one token with
`Contents: Read` access to both private repositories. `build.sh` performs the
same downloads automatically from `versions.yaml`.

### cc-proxy config

Mount a cc-proxy `cc-proxy-config.yaml` at `/home/agent/.cc-proxy/config.yaml:ro`.
See `config/cc-proxy-config.example.yaml`. The image starts a local
[cc-proxy](https://github.com/courage-zen/cc-proxy) relay on `127.0.0.1:15721`;
set the agent's `ANTHROPIC_BASE_URL=http://127.0.0.1:15721` (e.g. via multica
web dashboard `custom_env`) to route claude-code traffic through it.

### multica config

Mount a multica config at `/etc/multica/config.json:ro`. See
`config/multica-config.example.json`.

## Local Build

```sh
./build.sh [<arch>]
```

- `arch` — Target architecture: `amd64` or `arm64` (default: `amd64`)

The script reads versions from `versions.yaml`, downloads private release
binaries via `gh`, and tags the image `cc-sandbox-runtime:<version>-<arch>`.

## Version Management

Component versions are pinned in `versions.yaml`. To release a new version:

1. Bump `project.version` (and component versions as needed) in `versions.yaml`
2. Commit + push to main → CI builds and pushes both arches to GHCR
3. Tag and push:
   ```
   git tag v{project.version}
   git push origin v{project.version}
   ```
4. CI creates the GitHub Release with `cc-sandbox-runtime-<arch>.tar.gz` assets
