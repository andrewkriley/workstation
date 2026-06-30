#!/usr/bin/env bats
# Unit tests for sync_block_to_rc / append_to_rc in install-dotfiles.sh.
# Focus: managed blocks update in place when their content drifts, legacy
# (un-delimited) blocks migrate once, and unrelated RC content is preserved.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../install-dotfiles.sh"
  # Load just the helpers — the hook returns before the installer body runs.
  WORKSTATION_LIB_ONLY=1 source "$SCRIPT"
  DRY_RUN=false
  RC="$(mktemp)"
}

teardown() {
  rm -f "$RC"
}

@test "sync adds a managed block with sentinel markers" {
  sync_block_to_rc "$RC" "demo" "GUARD_STR" "export DEMO=1" "demo"
  run grep -c '# >>> workstation:demo >>>' "$RC"
  [ "$output" -eq 1 ]
  grep -qF '# <<< workstation:demo <<<' "$RC"
  grep -qF 'export DEMO=1' "$RC"
}

@test "sync is idempotent — identical content leaves the file byte-for-byte" {
  sync_block_to_rc "$RC" "demo" "GUARD_STR" "export DEMO=1" "demo"
  before="$(cat "$RC")"
  sync_block_to_rc "$RC" "demo" "GUARD_STR" "export DEMO=1" "demo"
  [ "$(cat "$RC")" = "$before" ]
}

@test "sync replaces a drifted managed block in place (no duplication)" {
  sync_block_to_rc "$RC" "demo" "GUARD_STR" "export DEMO=1" "demo"
  sync_block_to_rc "$RC" "demo" "GUARD_STR" "export DEMO=2" "demo"
  # Exactly one block; new content present, old content gone.
  run grep -c '# >>> workstation:demo >>>' "$RC"
  [ "$output" -eq 1 ]
  grep -qF 'export DEMO=2' "$RC"
  ! grep -qF 'export DEMO=1' "$RC"
}

@test "sync migrates a legacy un-delimited block and preserves surrounding lines" {
  cat >"$RC" <<'EOF'
# user's own line above
export USER_KEEP=yes

# legacy demo block
export DEMO=1

# user's own line below
export USER_KEEP2=yes
EOF
  sync_block_to_rc "$RC" "demo" "legacy demo block" "export DEMO=99" "demo"

  # Managed block now present with new content; legacy paragraph gone.
  grep -qF '# >>> workstation:demo >>>' "$RC"
  grep -qF 'export DEMO=99' "$RC"
  ! grep -qF '# legacy demo block' "$RC"
  ! grep -qF 'export DEMO=1' "$RC"

  # Unrelated user content untouched.
  grep -qF 'export USER_KEEP=yes' "$RC"
  grep -qF 'export USER_KEEP2=yes' "$RC"
}

@test "migration then re-run is idempotent" {
  cat >"$RC" <<'EOF'
# legacy demo block
export DEMO=1
EOF
  sync_block_to_rc "$RC" "demo" "legacy demo block" "export DEMO=99" "demo"
  after_migrate="$(cat "$RC")"
  sync_block_to_rc "$RC" "demo" "legacy demo block" "export DEMO=99" "demo"
  [ "$(cat "$RC")" = "$after_migrate" ]
}

@test "append_to_rc keeps add-once semantics (never clobbers an existing match)" {
  printf '%s\n' "parse_git_branch() { echo custom; }" >"$RC"
  before="$(cat "$RC")"
  append_to_rc "$RC" "parse_git_branch" "# ours
parse_git_branch() { echo ours; }" "shell prompt"
  [ "$(cat "$RC")" = "$before" ]
}
