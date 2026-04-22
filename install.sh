#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/templates"
TARGET_DIR="${HOME}/.codex"
CCG_SOURCE_DIR="${SCRIPT_DIR}/ccg"
CONFIG_BASE_TEMPLATE="${TEMPLATE_DIR}/config.base.toml"
EXA_SNIPPET_TEMPLATE="${TEMPLATE_DIR}/snippets/exa.toml"
GITHUB_SNIPPET_TEMPLATE="${TEMPLATE_DIR}/snippets/github.toml"
ROOT_KEYS=(
  model
  model_provider
  disable_response_storage
  plan_mode_reasoning_effort
  model_reasoning_effort
  tool_output_token_limit
  model_context_window
  model_auto_compact_token_limit
  sandbox_mode
  approval_policy
  approvals_reviewer
  personality
  web_search
)
BASE_TABLES=(
  profiles.multi
  model_providers.cpa-responses
  mcp_servers.context7
  mcp_servers.fetch
  mcp_servers.fetch.tools.fetch
  tui
  notice.model_migrations
  shell_environment_policy
  agents
  features
)
CURRENT_SHELL_PATH="${PATH}"
TTY_FD=""

log() {
  printf '[install] %s\n' "$1"
}

require_file() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    printf 'missing required file: %s\n' "$path" >&2
    exit 1
  fi
}

append_template() {
  local template_path="$1"
  local placeholder="$2"
  local value="$3"
  local output_path="$4"

  sed "s|${placeholder}|$(escape_sed_replacement "$value")|g" "$template_path" >>"$output_path"
  printf '\n' >>"$output_path"
}

copy_tree() {
  local source_dir="$1"
  local destination_dir="$2"

  mkdir -p "$destination_dir"
  cp -R "${source_dir}/." "$destination_dir/"
}

escape_sed_replacement() {
  printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

escape_toml_basic_string() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

init_prompt_input() {
  if [[ -t 0 ]]; then
    return
  fi

  if { exec {TTY_FD}</dev/tty; } 2>/dev/null; then
    return
  fi

  TTY_FD=""
}

close_prompt_input() {
  if [[ -n "$TTY_FD" ]]; then
    exec {TTY_FD}<&-
  fi
}

read_secret() {
  local prompt="$1"
  local value=""

  printf '%s' "$prompt" >&2

  if [[ -n "${TTY_FD}" ]]; then
    IFS= read -r -s value <&"$TTY_FD" || true
  else
    IFS= read -r -s value || true
  fi

  printf '\n' >&2
  printf '%s' "$value"
}

join_by_comma() {
  local first=1
  local item

  for item in "$@"; do
    if [[ $first -eq 1 ]]; then
      printf '%s' "$item"
      first=0
    else
      printf ',%s' "$item"
    fi
  done
}

build_managed_config() {
  local output_path="$1"

  sed "s|__SHELL_PATH__|$(escape_sed_replacement "$(escape_toml_basic_string "$CURRENT_SHELL_PATH")")|g" \
    "$CONFIG_BASE_TEMPLATE" >"$output_path"
  printf '\n' >>"$output_path"

  if [[ -n "$exa_api_key" ]]; then
    append_template "$EXA_SNIPPET_TEMPLATE" "__EXA_API_KEY__" "$exa_api_key" "$output_path"
  fi

  if [[ -n "$github_personal_access_token" ]]; then
    append_template "$GITHUB_SNIPPET_TEMPLATE" "__GITHUB_PERSONAL_ACCESS_TOKEN__" "$github_personal_access_token" "$output_path"
  fi
}

strip_managed_config() {
  local input_path="$1"
  local output_path="$2"
  local root_keys_csv="$3"
  local managed_tables_csv="$4"

  awk \
    -v root_keys_csv="$root_keys_csv" \
    -v managed_tables_csv="$managed_tables_csv" '
      function parse_header(line, header_name) {
        header_name = line
        sub(/^[[:space:]]*\[/, "", header_name)
        sub(/\].*$/, "", header_name)
        gsub(/[[:space:]]/, "", header_name)
        return header_name
      }

      BEGIN {
        split(root_keys_csv, root_key_items, ",")
        for (i in root_key_items) {
          if (root_key_items[i] != "") {
            managed_root_keys[root_key_items[i]] = 1
          }
        }

        split(managed_tables_csv, managed_table_items, ",")
        for (i in managed_table_items) {
          if (managed_table_items[i] != "") {
            managed_tables[managed_table_items[i]] = 1
          }
        }

        current_table = ""
        skip_block = 0
      }

      {
        if ($0 ~ /^[[:space:]]*\[[^]]+\]/) {
          current_table = parse_header($0)
          skip_block = (current_table in managed_tables)

          if (!skip_block) {
            print
          }
          next
        }

        if (skip_block) {
          next
        }

        if (current_table == "") {
          trimmed_line = $0
          sub(/^[[:space:]]+/, "", trimmed_line)

          if (trimmed_line ~ /^[A-Za-z0-9_.-]+[[:space:]]*=/) {
            split(trimmed_line, key_parts, "=")
            root_key = key_parts[1]
            sub(/[[:space:]]+$/, "", root_key)

            if (root_key in managed_root_keys) {
              next
            }
          }
        }

        print
      }
    ' "$input_path" >"$output_path"
}

split_config_sections() {
  local input_path="$1"
  local root_output_path="$2"
  local table_output_path="$3"

  awk \
    -v root_output_path="$root_output_path" \
    -v table_output_path="$table_output_path" '
      BEGIN {
        seen_table = 0
      }

      {
        if ($0 ~ /^[[:space:]]*\[[^]]+\]/) {
          seen_table = 1
        }

        if (seen_table) {
          print >>table_output_path
        } else {
          print >>root_output_path
        }
      }
    ' "$input_path"
}

merge_config() {
  local target_path="$1"
  local managed_config
  local managed_root
  local managed_tables_only
  local stripped_config
  local stripped_root
  local stripped_tables_only
  local merged_config
  local managed_tables=("${BASE_TABLES[@]}")
  local root_keys_csv
  local managed_tables_csv

  if [[ -n "$exa_api_key" ]]; then
    managed_tables+=(mcp_servers.exa mcp_servers.exa.env)
  fi

  if [[ -n "$github_personal_access_token" ]]; then
    managed_tables+=(mcp_servers.github mcp_servers.github.env)
  fi

  root_keys_csv="$(join_by_comma "${ROOT_KEYS[@]}")"
  managed_tables_csv="$(join_by_comma "${managed_tables[@]}")"
  managed_config="$(mktemp)"
  managed_root="$(mktemp)"
  managed_tables_only="$(mktemp)"
  stripped_config="$(mktemp)"
  stripped_root="$(mktemp)"
  stripped_tables_only="$(mktemp)"
  merged_config="$(mktemp)"

  build_managed_config "$managed_config"

  if [[ ! -f "$target_path" ]]; then
    mv "$managed_config" "$target_path"
    rm -f "$managed_root" "$managed_tables_only" "$stripped_config" "$stripped_root" "$stripped_tables_only" "$merged_config"
    return
  fi

  strip_managed_config "$target_path" "$stripped_config" "$root_keys_csv" "$managed_tables_csv"
  split_config_sections "$managed_config" "$managed_root" "$managed_tables_only"
  split_config_sections "$stripped_config" "$stripped_root" "$stripped_tables_only"

  cat "$managed_root" >"$merged_config"

  if grep -q '[^[:space:]]' "$stripped_root"; then
    printf '\n' >>"$merged_config"
    cat "$stripped_root" >>"$merged_config"
  fi

  if grep -q '[^[:space:]]' "$managed_tables_only"; then
    printf '\n' >>"$merged_config"
    cat "$managed_tables_only" >>"$merged_config"
  fi

  if grep -q '[^[:space:]]' "$stripped_tables_only"; then
    printf '\n' >>"$merged_config"
    cat "$stripped_tables_only" >>"$merged_config"
  fi

  mv "$merged_config" "$target_path"
  rm -f "$managed_config" "$managed_root" "$managed_tables_only" "$stripped_config" "$stripped_root" "$stripped_tables_only"
}

require_file "$CONFIG_BASE_TEMPLATE"
require_file "$EXA_SNIPPET_TEMPLATE"
require_file "$GITHUB_SNIPPET_TEMPLATE"
require_file "$CCG_SOURCE_DIR/codeagent-wrapper"

trap close_prompt_input EXIT
init_prompt_input

log 'Installing @fission-ai/openspec'
npm install -g @fission-ai/openspec@latest

exa_api_key="${EXA_API_KEY:-}"
github_personal_access_token="${GITHUB_PERSONAL_ACCESS_TOKEN:-}"

if [[ -z "$exa_api_key" ]]; then
  exa_api_key="$(read_secret 'EXA_API_KEY (press Enter to skip): ')"
else
  log 'Using EXA_API_KEY from environment'
fi

if [[ -z "$github_personal_access_token" ]]; then
  github_personal_access_token="$(read_secret 'GITHUB_PERSONAL_ACCESS_TOKEN (press Enter to skip): ')"
else
  log 'Using GITHUB_PERSONAL_ACCESS_TOKEN from environment'
fi

mkdir -p "$TARGET_DIR"

log 'Copying templates'
copy_tree "${TEMPLATE_DIR}/agents" "${TARGET_DIR}/agents"
copy_tree "${TEMPLATE_DIR}/agents-prompts" "${TARGET_DIR}/agents-prompts"
copy_tree "${TEMPLATE_DIR}/rules" "${TARGET_DIR}/rules"
copy_tree "${TEMPLATE_DIR}/skills" "${TARGET_DIR}/skills"
cp "${TEMPLATE_DIR}/AGENTS.md" "${TARGET_DIR}/AGENTS.md"
cp "${TEMPLATE_DIR}/RTK.md" "${TARGET_DIR}/RTK.md"

log 'Installing ccg directory'
copy_tree "$CCG_SOURCE_DIR" "${TARGET_DIR}/ccg"

merge_config "${TARGET_DIR}/config.toml"

log "Installed to ${TARGET_DIR}"
