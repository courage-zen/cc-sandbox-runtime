#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARCH="${1:-amd64}"

# Docker daemon pre-check
docker info > /dev/null 2>&1 || { echo "Error: Docker is not available or daemon is not running" >&2; exit 1; }

# Validate ARCH
if [ "$ARCH" != "amd64" ] && [ "$ARCH" != "arm64" ]; then
    echo "Error: ARCH must be 'amd64' or 'arm64'" >&2
    exit 1
fi

# Validate versions.yaml exists
if [ ! -f "${SCRIPT_DIR}/versions.yaml" ]; then
    echo "Error: versions.yaml not found: ${SCRIPT_DIR}/versions.yaml" >&2
    exit 1
fi

# Read versions from YAML
PROJECT_VERSION=$(python3 -c "import yaml; print(yaml.safe_load(open('${SCRIPT_DIR}/versions.yaml'))['project']['version'])" 2>&1) || {
    echo "Error: failed to read project version" >&2; exit 1
}
CC_PROXY_VERSION=$(python3 -c "import yaml; print(yaml.safe_load(open('${SCRIPT_DIR}/versions.yaml'))['cc_proxy']['version'])" 2>&1) || {
    echo "Error: failed to read cc_proxy version" >&2; exit 1
}
MULTICA_VERSION=$(python3 -c "import yaml; print(yaml.safe_load(open('${SCRIPT_DIR}/versions.yaml'))['multica']['version'])" 2>&1) || {
    echo "Error: failed to read multica version" >&2; exit 1
}
MULTICA_STDIO_MCP_PROXY_VERSION=$(python3 -c "import yaml; print(yaml.safe_load(open('${SCRIPT_DIR}/versions.yaml'))['multica_stdio_mcp_proxy']['version'])" 2>&1) || {
    echo "Error: failed to read multica_stdio_mcp_proxy version" >&2; exit 1
}
CLAUDE_CODE_VERSION=$(python3 -c "import yaml; print(yaml.safe_load(open('${SCRIPT_DIR}/versions.yaml'))['claude_code']['version'])" 2>&1) || {
    echo "Error: failed to read claude_code version" >&2; exit 1
}

TAG="cc-sandbox-runtime:${PROJECT_VERSION}-${ARCH}"

echo "Building: TAG=${TAG}"

mkdir -p "${SCRIPT_DIR}/binaries/${ARCH}"
# cc-proxy and multica-stdio-mcp-proxy are private releases: download with
# the locally authenticated gh (CI uses the CC_PROXY_TOKEN secret)
gh release download "v${CC_PROXY_VERSION}" -R courage-zen/cc-proxy \
    -p "cc-proxy-${ARCH}" -O "${SCRIPT_DIR}/binaries/${ARCH}/cc-proxy" --clobber
chmod +x "${SCRIPT_DIR}/binaries/${ARCH}/cc-proxy"
gh release download "v${MULTICA_STDIO_MCP_PROXY_VERSION}" -R courage-zen/multica-stdio-mcp-proxy \
    -p "multica-stdio-mcp-proxy-linux-${ARCH}" -O "${SCRIPT_DIR}/binaries/${ARCH}/multica-stdio-mcp-proxy" --clobber
chmod +x "${SCRIPT_DIR}/binaries/${ARCH}/multica-stdio-mcp-proxy"

BUILD_ARGS=(
    "--build-arg" "MULTICA_VERSION=${MULTICA_VERSION}"
    "--build-arg" "CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}"
    "--build-arg" "TARGETARCH=${ARCH}"
)

echo "  PROJECT_VERSION=${PROJECT_VERSION}"
echo "  CC_PROXY_VERSION=${CC_PROXY_VERSION}"
echo "  MULTICA_VERSION=${MULTICA_VERSION}"
echo "  MULTICA_STDIO_MCP_PROXY_VERSION=${MULTICA_STDIO_MCP_PROXY_VERSION}"
echo "  CLAUDE_CODE_VERSION=${CLAUDE_CODE_VERSION}"

docker build --progress=plain -f "${SCRIPT_DIR}/Dockerfile" "${BUILD_ARGS[@]}" -t "${TAG}" "${SCRIPT_DIR}" || {
    echo "Error: docker build failed for ${TAG}" >&2; exit 1
}
