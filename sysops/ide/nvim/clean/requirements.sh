#!/usr/bin/env bash
set -e

APT_PACKAGES="universal-ctags wl-clipboard shellcheck"
NPM_PACKAGES="jsonlint"
PIP_PACKAGES="yamllint"

echo "=== System packages ==="
for pkg in $APT_PACKAGES; do
  if ! dpkg -l $pkg > /dev/null 2>&1; then
    echo "Installing $pkg..."
    sudo apt install -y $pkg
  else
    echo "✓ $pkg"
  fi
done

echo ""
echo "=== npm packages ==="
for pkg in $NPM_PACKAGES; do
  if ! npm list -g $pkg > /dev/null 2>&1; then
    echo "Installing $pkg..."
    npm install -g $pkg
  else
    echo "✓ $pkg"
  fi
done

echo ""
echo "=== pip packages ==="
for pkg in $PIP_PACKAGES; do
  if ! pip show $pkg > /dev/null 2>&1; then
    echo "Installing $pkg..."
    pip install $pkg 2>/dev/null || pip install $pkg --break-system-packages 2>/dev/null || pip3 install $pkg
  else
    echo "✓ $pkg"
  fi
done

echo ""
echo "Done."
