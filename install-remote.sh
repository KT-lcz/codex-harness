#!/usr/bin/env bash

set -euo pipefail

REPO_SLUG="${CODEX_HARNESS_REPO:-KT-lcz/codex-harness}"
REPO_REF="${CODEX_HARNESS_REF:-master}"
ARCHIVE_URL="${CODEX_HARNESS_ARCHIVE_URL:-https://codeload.github.com/${REPO_SLUG}/tar.gz/${REPO_REF}}"
WORK_DIR="$(mktemp -d)"

log() {
  printf '[bootstrap] %s\n' "$1"
}

cleanup() {
  rm -rf "$WORK_DIR"
}

require_command() {
  local command_name="$1"

  if ! command -v "$command_name" >/dev/null 2>&1; then
    printf 'missing required command: %s\n' "$command_name" >&2
    exit 1
  fi
}

trap cleanup EXIT

require_command curl
require_command tar
require_command bash

ARCHIVE_PATH="${WORK_DIR}/codex-harness.tar.gz"

log "Downloading ${REPO_SLUG}@${REPO_REF}"
curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"

log 'Extracting archive'
tar -xzf "$ARCHIVE_PATH" -C "$WORK_DIR"

INSTALL_SCRIPT="$(find "$WORK_DIR" -mindepth 2 -maxdepth 2 -type f -name install.sh | head -n 1)"

if [[ -z "$INSTALL_SCRIPT" ]]; then
  printf 'failed to locate install.sh in downloaded archive\n' >&2
  exit 1
fi

log 'Running install.sh'
bash "$INSTALL_SCRIPT" "$@"
