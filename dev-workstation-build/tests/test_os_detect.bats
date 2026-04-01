#!/usr/bin/env bats
# tests/test_os_detect.bats — Unit tests for lib/os.sh detect_os()

setup() {
  source "$(dirname "$BATS_TEST_FILENAME")/../lib/os.sh"
}

# ── detect_os() ───────────────────────────────────────────────────────────────

@test "detect_os returns a known platform string" {
  result="$(detect_os)"
  [[ "$result" == "macos-arm" ]] \
    || [[ "$result" == "macos-intel" ]] \
    || [[ "$result" == "linux-x86" ]] \
    || [[ "$result" == "linux-arm" ]]
}

@test "detect_os returns non-empty string" {
  result="$(detect_os)"
  [ -n "$result" ]
}

@test "detect_os does not return 'unknown' on supported CI platforms" {
  result="$(detect_os)"
  [ "$result" != "unknown" ]
}

# ── set_pkg_manager() ─────────────────────────────────────────────────────────

@test "set_pkg_manager sets PKG_MANAGER to brew or apt" {
  set_pkg_manager
  [[ "$PKG_MANAGER" == "brew" ]] || [[ "$PKG_MANAGER" == "apt" ]]
}

@test "set_pkg_manager exports PKG_MANAGER" {
  set_pkg_manager
  printenv PKG_MANAGER >/dev/null
}

# ── pkg_installed() ───────────────────────────────────────────────────────────

@test "pkg_installed returns true for bash (always present)" {
  pkg_installed bash
}

@test "pkg_installed returns false for a nonexistent command" {
  run pkg_installed __nonexistent_command_xyz__
  [ "$status" -ne 0 ]
}

# ── macOS-specific ────────────────────────────────────────────────────────────

@test "detect_os returns macos-arm on Apple Silicon" {
  if [[ "$(uname -s)" != "Darwin" ]] || [[ "$(uname -m)" != "arm64" ]]; then
    skip "not running on Apple Silicon"
  fi
  [ "$(detect_os)" = "macos-arm" ]
}

@test "detect_os returns macos-intel on Intel Mac" {
  if [[ "$(uname -s)" != "Darwin" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
    skip "not running on Intel Mac"
  fi
  [ "$(detect_os)" = "macos-intel" ]
}

# ── Linux-specific ────────────────────────────────────────────────────────────

@test "detect_os returns linux-x86 on Linux x86_64" {
  if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "x86_64" ]]; then
    skip "not running on Linux x86_64"
  fi
  [ "$(detect_os)" = "linux-x86" ]
}

@test "detect_os returns linux-arm on Linux aarch64" {
  if [[ "$(uname -s)" != "Linux" ]] || [[ "$(uname -m)" != "aarch64" ]]; then
    skip "not running on Linux aarch64"
  fi
  [ "$(detect_os)" = "linux-arm" ]
}
