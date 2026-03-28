#!/bin/sh
set -e

REPO="ronan-zelta/curl-ui"
BASE_URL="https://github.com/${REPO}/releases/latest/download"

OS=$(uname -s)
ARCH=$(uname -m)

case "$OS" in
  Darwin) os="darwin" ;;
  Linux)  os="linux" ;;
  *)
    echo "Unsupported OS: $OS"
    exit 1
    ;;
esac

case "$ARCH" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *)
    echo "Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

if [ "$os" = "linux" ] && [ "$arch" = "arm64" ]; then
  echo "No Linux arm64 build available"
  exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

if [ "$os" = "darwin" ]; then
  FILE="httpclient-darwin-${arch}.zip"
  echo "Downloading ${FILE}..."
  curl -fSL "${BASE_URL}/${FILE}" -o "${TMPDIR}/${FILE}"
  unzip -q "${TMPDIR}/${FILE}" -d "${TMPDIR}"
  echo "Installing to /Applications..."
  rm -rf /Applications/httpclient.app
  mv "${TMPDIR}/httpclient.app" /Applications/
  echo "Installed to /Applications/httpclient.app"
else
  FILE="httpclient-linux-amd64.tar.gz"
  echo "Downloading ${FILE}..."
  curl -fSL "${BASE_URL}/${FILE}" -o "${TMPDIR}/${FILE}"
  tar xzf "${TMPDIR}/${FILE}" -C "${TMPDIR}"
  INSTALL_DIR="/usr/local/bin"
  echo "Installing to ${INSTALL_DIR}..."
  sudo install -m 755 "${TMPDIR}/httpclient" "${INSTALL_DIR}/httpclient"
  echo "Installed to ${INSTALL_DIR}/httpclient"
fi
