#!/bin/bash
# Deploy babyFoodOpenAI without global npm/Homebrew.
#
# Usage:
#   ./deploy-openai-function.sh login     # log in to Firebase (browser)
#   ./deploy-openai-function.sh set-key   # set OPENAI_API_KEY secret (required once)
#   ./deploy-openai-function.sh           # deploy babyFoodOpenAI only
#
# NOTE: You do NOT need APPLE_KEY_ID or other Apple secrets for this deploy.
# Those are only for appleConsumptionWebhook (subscription webhooks).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
TOOLS="$ROOT/.tools"
NODE_DIR="$TOOLS/node"
NODE_VER="v22.14.0"
PROJECT="baby-food-834f7"
ARCH="$(uname -m)"
if [ "$ARCH" = "arm64" ]; then
  NODE_PKG="node-${NODE_VER}-darwin-arm64"
else
  NODE_PKG="node-${NODE_VER}-darwin-x64"
fi

ensure_node() {
  if [ ! -x "$NODE_DIR/bin/node" ]; then
    echo "→ Downloading Node.js $NODE_VER ($ARCH)..."
    mkdir -p "$TOOLS"
    curl -fsSL "https://nodejs.org/dist/${NODE_VER}/${NODE_PKG}.tar.gz" -o "$TOOLS/node.tar.gz"
    rm -rf "$NODE_DIR"
    mkdir -p "$NODE_DIR"
    tar -xzf "$TOOLS/node.tar.gz" -C "$NODE_DIR" --strip-components=1
    rm "$TOOLS/node.tar.gz"
    echo "✓ Node installed to $NODE_DIR"
  fi
  export PATH="$NODE_DIR/bin:$PATH"
  export npm_config_prefix="$NODE_DIR"
}

ensure_firebase() {
  if ! command -v firebase >/dev/null 2>&1; then
    echo "→ Installing firebase-tools..."
    npm install -g firebase-tools
    echo "✓ firebase-tools installed"
  fi
}

ensure_login() {
  if ! firebase login:list 2>/dev/null | grep -q "@"; then
    echo "→ Opening Firebase login in your browser..."
    firebase login
  fi
}

ensure_openai_secret() {
  if firebase functions:secrets:access OPENAI_API_KEY --project "$PROJECT" >/dev/null 2>&1; then
    echo "✓ OPENAI_API_KEY secret is configured"
    return 0
  fi
  echo ""
  echo "OPENAI_API_KEY is not set in Firebase Secret Manager."
  echo "Run this script with 'set-key' first:"
  echo "  ./deploy-openai-function.sh set-key"
  echo ""
  exit 1
}

set_openai_key() {
  ensure_node
  ensure_firebase
  ensure_login
  echo ""
  echo "Paste your OpenAI API key (starts with sk-). Input is hidden:"
  read -rs OPENAI_KEY
  echo ""
  if [ -z "$OPENAI_KEY" ]; then
    echo "Error: API key cannot be empty."
    exit 1
  fi
  printf '%s' "$OPENAI_KEY" | firebase functions:secrets:set OPENAI_API_KEY --project "$PROJECT"
  echo "✓ OPENAI_API_KEY saved to Secret Manager"
}

deploy_function() {
  ensure_node
  ensure_firebase
  ensure_login
  ensure_openai_secret

  echo "→ Installing function dependencies..."
  npm --prefix "$ROOT/functions" install

  cd "$ROOT"
  echo "→ Deploying babyFoodOpenAI only (no Apple secrets needed)..."
  firebase deploy --only functions:babyFoodOpenAI --project "$PROJECT" --non-interactive

  echo "✓ Deploy complete"
}

ensure_node
ensure_firebase

case "${1:-deploy}" in
  login)
    ensure_login
  ;;
  set-key)
    set_openai_key
  ;;
  deploy|"")
    deploy_function
  ;;
  *)
    echo "Unknown command: $1"
    echo "Usage: $0 [login|set-key|deploy]"
    exit 1
  ;;
esac
