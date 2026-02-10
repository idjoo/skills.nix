#!/usr/bin/env bash
set -euo pipefail

# Fetch the latest version from npm registry
LATEST=$(curl -sf https://registry.npmjs.org/skills/latest | jq -r '.version')
CURRENT=$(grep -oP 'version = "\K[^"]+' package.nix)

if [ "$LATEST" = "$CURRENT" ]; then
  echo "Already up to date: $CURRENT"
  echo "updated=false" >>"${GITHUB_OUTPUT:-/dev/null}"
  exit 0
fi

echo "Updating $CURRENT -> $LATEST"

# Prefetch the new tarball hash
HASH=$(nix-prefetch-url "https://registry.npmjs.org/skills/-/skills-${LATEST}.tgz" 2>/dev/null)
SRI=$(nix hash convert --hash-algo sha256 --to sri "$HASH")

# Update package.nix
sed -i "s|version = \"$CURRENT\"|version = \"$LATEST\"|" package.nix
sed -i "s|hash = \"sha256-.*\"|hash = \"$SRI\"|" package.nix

echo "Updated to $LATEST (hash: $SRI)"
echo "updated=true" >>"${GITHUB_OUTPUT:-/dev/null}"
echo "version=$LATEST" >>"${GITHUB_OUTPUT:-/dev/null}"
