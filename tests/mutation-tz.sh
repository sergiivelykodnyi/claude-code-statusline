#!/bin/bash
# tests/mutation-tz.sh — the gate that keeps the timezone test gap closed
# (quick task 260912-x11, WR-01 acceptance bar).
#
# A green suite proves nothing about the timezone path unless a BROKEN
# timezone path makes it red. tests/run.sh section 4b is the first half of
# that claim; this script proves the second half. It mutates a THROWAWAY COPY
# of the product, runs the copied suite against it, and asserts the suite goes
# red FOR THE RIGHT REASON — at least one `FAIL non-UTC render ...` line, not
# some incidental failure elsewhere.
#
# A SURVIVOR means the suite cannot see the timezone path: the product's zone
# handling was deleted or broken and every check still passed. That is exactly
# the state the 260912-vgx review found (242 checks, 0 failures with a
# hard-coded TZOFF=0) and exactly what this gate exists to prevent coming back.
#
# The repo is NEVER written to. Every mutation is applied inside a fresh
# mktemp -d directory; `git status --porcelain` is byte-identical before and
# after a run. The copied tests/ tree includes this script too, but only
# run.sh inside it is ever executed — the gate does not recurse.
#
# Standalone and opt-in, like tests/probe-kit-add.sh. It is deliberately NOT
# called from tests/run.sh: run.sh stays hermetic and fast, and this gate runs
# the whole suite twice.
#
# Usage: /bin/bash tests/mutation-tz.sh
# Exit status: 0 = every mutant was killed; non-zero = at least one survivor.
#
# bash 3.2-safe (macOS host /bin/bash); no sed -i, no date -d / date -r.

cd "$(dirname "$0")/.." || exit 1
SRC=kit/files/home/.claude/statusline.sh

MUTANTS=0
FAILS=0

# run_mutant NAME REPLACEMENT_LINE
# Copies kit/ and tests/ into a scratch tree, rewrites the TZOFF assignment
# line with REPLACEMENT_LINE, runs the copied suite, and reports one PASS/FAIL.
run_mutant() {
  name=$1
  repl=$2
  MUTANTS=$(( MUTANTS + 1 ))

  # T-x11-01: `work` comes only from mktemp -d, is always double-quoted, and
  # the rm -rf below is reached only after this succeeded. Never a literal or
  # derived path.
  work=$(mktemp -d "${TMPDIR:-/tmp}/statusline-mutation.XXXXXX") || {
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL mutant [%s]: mktemp -d failed\n' "$name"
    return 1
  }

  # run.sh cd's to its own dirname/.., so a copy of just these two trees is
  # self-contained; cp -R preserves the exec bit run.sh asserts on $SL, and
  # its HERE=${PWD##*/} fallback self-adjusts to the scratch directory name.
  cp -R kit tests "$work"/ || {
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL mutant [%s]: could not copy kit/ and tests/ into the scratch tree\n' "$name"
    rm -rf "$work"
    return 1
  }

  # Rewrite the TZOFF line in the COPY. awk, not sed -i (BSD/GNU divergence,
  # CLAUDE.md); the replacement is passed in with -v so nothing is re-parsed
  # as a regex or a shell word.
  awk -v repl="$repl" '
    $0 ~ /^  TZOFF=\$\(tz_offset_secs/ { print repl; next }
    { print }
  ' "$SRC" > "$work/$SRC.mut" && mv "$work/$SRC.mut" "$work/$SRC" \
    && chmod +x "$work/$SRC" || {
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL mutant [%s]: awk rewrite failed\n' "$name"
    rm -rf "$work"
    return 1
  }

  # Applicability guard: if the copy still equals the pristine source, the
  # mutation did not apply and a green suite below would mean nothing. cmp
  # avoids any regex-escaping question about the replacement text.
  if cmp -s "$SRC" "$work/$SRC"; then
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL mutant [%s]: mutation did not apply — the anchor line\n' "$name"
    printf '       "  TZOFF=$(tz_offset_secs ..." moved or was reworded in %s.\n' "$SRC"
    printf '       Re-point the awk match in tests/mutation-tz.sh at the new line.\n'
    rm -rf "$work"
    return 1
  fi

  /bin/bash "$work/tests/run.sh" > "$work/run.log" 2>&1
  status=$?
  killed=$(grep -c '^FAIL non-UTC render' "$work/run.log" | tr -d '[:space:]')

  if [ "$status" -ne 0 ] && [ "$killed" -gt 0 ]; then
    printf 'PASS mutant [%s] killed: %s non-UTC render check(s) went red\n' "$name" "$killed"
  else
    FAILS=$(( FAILS + 1 ))
    printf 'FAIL mutant [%s]: suite survived the mutant\n' "$name"
    printf '       suite exit status: %s, FAIL non-UTC render lines: %s\n' "$status" "$killed"
    printf '       mutant suite summary: %s\n' "$(tail -1 "$work/run.log")"
    printf '       The timezone path is invisible to the suite. Fix tests/run.sh\n'
    printf '       section 4b — never loosen this gate.\n'
  fi

  rm -rf "$work"
}

# Mutant 1 — deletes zone handling from the product outright. This is the exact
# mutation the 260912-vgx review used to prove the gap.
run_mutant 'offset dropped' '  TZOFF=0'

# Mutant 2 — keeps the offset but throws away the minutes. No whole-hour zone
# can catch this one; it is what makes the sub-hour zone table in run.sh
# section 4b mechanically load-bearing rather than a stylistic choice.
run_mutant 'offset rounded to hours' \
  '  TZOFF=$(( $(tz_offset_secs "${NOW_Z##* }") / 3600 * 3600 ))'

printf '%s mutants, %s survivors\n' "$MUTANTS" "$FAILS"
[ "$FAILS" -eq 0 ]
