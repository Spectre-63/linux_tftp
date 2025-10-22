#!/bin/bash
# =============================================================================
# common.sh — Shared logging, formatting, and summary functions for ops scripts
# =============================================================================

# --- Timestamp generator -----------------------------------------------------
timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

# --- Log level control -------------------------------------------------------
LOG_LEVEL=${LOG_LEVEL:-info}

declare -A LOG_LEVELS=(
  [debug]=0
  [info]=1
  [warn]=2
  [error]=3
)

should_log() {
  local level=$1
  [[ ${LOG_LEVELS[$level]} -ge ${LOG_LEVELS[$LOG_LEVEL]} ]] && return 0 || return 1
}

# --- Output formatting helpers ----------------------------------------------
log_debug() { should_log debug && echo -e "$(timestamp)  \033[1;36m[DEBUG]\033[0m $*"; }
info()      { should_log info  && echo -e "$(timestamp)  \033[1;34m[INFO]\033[0m  $*"; }
pass()      { should_log info  && echo -e "$(timestamp)  \033[1;32m[PASS]\033[0m  $*"; }
warn()      { should_log warn  && echo -e "$(timestamp)  \033[1;33m[WARN]\033[0m  $*"; }
fail()      { should_log error && echo -e "$(timestamp)  \033[1;31m[FAIL]\033[0m  $*"; }

# --- Visual helpers ----------------------------------------------------------
hr() { echo "--------------------------------------------------------------------------------"; }

log_section() {
  # Usage: log_section "Section Title"
  local title="$1"
  echo ""
  echo -e "$(timestamp)  \033[1;35m==========[ ${title^^} ]==========\033[0m"
}

# --- Summary reporter --------------------------------------------------------
log_summary() {
  echo ""
  hr
  echo -e "$(timestamp)  \033[1;36m[SUMMARY]\033[0m  Generating results summary..."

  local tmp_log=$(mktemp)
  tee "$tmp_log" >/dev/null
  local pass_count warn_count fail_count
  pass_count=$(grep -c '\[PASS\]' "$tmp_log" 2>/dev/null || echo 0)
  warn_count=$(grep -c '\[WARN\]' "$tmp_log" 2>/dev/null || echo 0)
  fail_count=$(grep -c '\[FAIL\]' "$tmp_log" 2>/dev/null || echo 0)
  rm -f "$tmp_log"

  echo -e "$(timestamp)  \033[1;32mPASS:\033[0m $pass_count"
  echo -e "$(timestamp)  \033[1;33mWARN:\033[0m $warn_count"
  echo -e "$(timestamp)  \033[1;31mFAIL:\033[0m $fail_count"

  # --- Color-adaptive result block ------------------------------------------
  if (( fail_count > 0 )); then
    echo -e "\033[1;41m\033[97m $(timestamp)  [RESULT]  One or more critical checks FAILED. \033[0m"
    return 1
  elif (( warn_count > 0 )); then
    echo -e "\033[1;43m\033[30m $(timestamp)  [RESULT]  Completed with warnings. \033[0m"
    return 0
  else
    echo -e "\033[1;42m\033[30m $(timestamp)  [RESULT]  All checks passed successfully. \033[0m"
    return 0
  fi
}
