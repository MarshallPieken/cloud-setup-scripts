#!/usr/bin/env bash
# Sync a project folder to a remote instance over SSH with rsync.
# Excludes the heavy stuff (.venv, node_modules), top-level data/, and every .env file
# (*.example templates still ship). rsync protects excluded files on the instance from
# --delete, so secrets and data that live only on the instance are NEVER touched by this.
#
# Usage (from anywhere; it syncs the folder one level above this script):
#   scripts/deploy-sync.sh ec2-user@203.0.113.10
#   scripts/deploy-sync.sh ec2-user@203.0.113.10 ~/keys/demo.pem      # with an SSH key
#
# Pass only user@host: the destination folder is added by this script. It defaults to ~/app/
# (a deliberately generic name); override with REMOTE_DIR=name scripts/deploy-sync.sh ...
#
# Build anything that ships prebuilt (e.g. a frontend dist/) BEFORE syncing.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST="${1:?usage: deploy-sync.sh user@host [path/to/key.pem]}"
KEY="${2:-}"
REMOTE_DIR="${REMOTE_DIR:-app}"

# user@host only. A ":path" or "/..." after the host would be appended to the destination and make
# rsync create a junk directory. Brackets are stripped first so IPv6 hosts like [2001:db8::1] pass.
HOST_PART="${DEST#*@}"
HOST_PART="${HOST_PART//\[*\]/}"
if [[ "$HOST_PART" == *:* || "$HOST_PART" == */* ]]; then
  echo "! '$DEST' includes a path. Pass only user@host (e.g. ec2-user@203.0.113.10);" >&2
  echo "  this script always syncs to ~/$REMOTE_DIR/ on the instance." >&2
  exit 1
fi

# Plain public-key SSH only: never fall back to GSSAPI/Kerberos, whatever the system ssh_config says
SSH="ssh -o GSSAPIAuthentication=no -o PreferredAuthentications=publickey"
[ -n "$KEY" ] && SSH="$SSH -o IdentitiesOnly=yes -i $KEY"

# rsync uses the first matching rule, so the *.example include must come before the .env* exclude
rsync -avz --delete \
  --exclude='node_modules' --exclude='.venv' --exclude='venv' \
  --exclude='__pycache__' --exclude='*.pyc' \
  --exclude='.git' --exclude='.pytest_cache' --exclude='.ruff_cache' \
  --exclude='/data' \
  --include='.env*.example' --exclude='.env' --exclude='.env.*' \
  -e "$SSH" ./ "$DEST:~/$REMOTE_DIR/"

echo "✓ synced to $DEST:~/$REMOTE_DIR/"
