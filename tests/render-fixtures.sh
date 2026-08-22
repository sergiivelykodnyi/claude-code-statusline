#!/bin/bash
# tests/render-fixtures.sh — dump RAW fixture renders (escape sequences kept)
# for byte-for-byte comparison across install paths and environments
# (D-39, PORT-01, PORT-04). bash 3.2-safe, BSD/GNU-neutral: runs on the macOS
# host /bin/bash and inside a Docker Sandbox unchanged.
#
# Usage: /bin/bash tests/render-fixtures.sh OUTDIR
#   Writes OUTDIR/repo/<fixture>.out through the repo script and, when the
#   installed script is executable, OUTDIR/installed/<fixture>.out through
#   the installed path (symlink/copy on the host, kit-delivered file in the
#   sandbox), then diff -r's the two: installed == repo is the per-environment
#   half of PORT-04. Two environments' OUTDIR/repo trees are then diffed
#   against each other on the host for PORT-01.
#
# Env inputs:
#   INSTALLED         path of the installed script
#                     (default: $HOME/.claude/statusline.sh)
#   REQUIRE_INSTALLED non-empty -> a missing / non-executable INSTALLED is a
#                     FAIL (exit 1) instead of an INFO skip (sandbox strictness)
#
# Exit status: 0 on success; 1 on any byte difference or a REQUIRE_INSTALLED
# miss (helpers may exit non-zero — only statusline.sh itself is never-fail).
#
# Determinism: all 7 fixtures render time-independently — resets_at 0 renders
# "(now)" forever, and empty/malformed fall back to the repo directory
# basename, identical in the sandbox because the workspace is mounted at the
# same absolute path. Raw bytes are compared on purpose: PORT-01 "identical
# output" includes the color codes, so nothing is stripped here.
# The Fable path is disabled by the exported kill switch (D-64), so the dumps
# never depend on network reachability or credentials in either environment.

cd "$(dirname "$0")/.." || exit 1
SL=kit/files/home/.claude/statusline.sh
export STATUSLINE_NO_FABLE=1   # D-64: dumps never depend on network or credentials
OUT=${1:?usage: tests/render-fixtures.sh OUTDIR}
INSTALLED=${INSTALLED:-$HOME/.claude/statusline.sh}

# Output layout: OUT/repo always; OUT/installed only when the installed path
# is executable (the exec bit is part of what PORT-04 exercises).
mkdir -p "$OUT/repo" || exit 1
have_installed=0
if [ -x "$INSTALLED" ]; then
  mkdir -p "$OUT/installed" || exit 1
  have_installed=1
fi

# Clear only stale *.out renders inside the two subdirectories (T-03-05) —
# never a recursive delete of OUT itself.
rm -f "$OUT/repo"/*.out "$OUT/installed"/*.out

n_rendered=0
for f in tests/fixtures/*.json; do
  n=${f##*/}; n=${n%.json}
  # Repo path: the harness discipline — host /bin/bash 3.2 is what runs it.
  /bin/bash "$SL" < "$f" > "$OUT/repo/$n.out" 2>/dev/null
  # Installed path: executed DIRECTLY so the shebang and exec bit through the
  # symlink / kit copy are what gets exercised (PORT-04).
  if [ "$have_installed" -eq 1 ]; then
    "$INSTALLED" < "$f" > "$OUT/installed/$n.out" 2>/dev/null
  fi
  n_rendered=$(( n_rendered + 1 ))
done

printf 'INFO rendered %d fixtures to %s/repo\n' "$n_rendered" "$OUT"

if [ "$have_installed" -eq 1 ]; then
  printf 'INFO installed path: %s\n' "$INSTALLED"
  if diff -r "$OUT/repo" "$OUT/installed"; then
    printf 'PASS installed path renders byte-identical to repo path (PORT-04): %s == %s\n' \
      "$OUT/installed" "$OUT/repo"
  else
    printf 'FAIL installed path differs from repo path (PORT-04): %s != %s\n' \
      "$OUT/installed" "$OUT/repo"
    exit 1
  fi
elif [ -n "${REQUIRE_INSTALLED:-}" ]; then
  printf 'FAIL installed path absent or not executable (REQUIRE_INSTALLED set): %s\n' "$INSTALLED"
  exit 1
else
  printf 'INFO installed path absent or not executable — installed half skipped: %s\n' "$INSTALLED"
fi

exit 0
