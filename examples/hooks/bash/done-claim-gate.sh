#!/usr/bin/env bash
# done-claim-gate.sh: a Stop hook that asks one question, is the "done" supported?
#
# Register it in .claude/settings.json:
#   {"hooks": {"Stop": [{"hooks": [{"type": "command",
#      "command": ".claude/hooks/done-claim-gate.sh"}]}]}}
#
# The event name is `Stop`. Not `stop`, not `on_stop`. An unrecognized event name is
# silently ignored by the platform, so a misspelling here produces a hook that is
# installed, committed, and has never run once. In a survey of 500 public setups on
# 2026-09-05, 7 of the 248 that register hooks had at least one such name, and every
# one of them was a misspelling of a real event.
#
# WHAT IT CHECKS. A turn that claims completion should name the object it completed
# against: a test, a file, a command, a URL. A turn that claims completion and offers
# only a generic passing token ("exit 0", "all tests pass", "N passed") has cited
# something that would be equally true if the work had not been done.
#
# IT FAILS OPEN, ON PURPOSE. If the transcript cannot be read or parsed, it exits 0
# and says nothing. A gate that blocks work it does not understand gets deleted within
# a day, and then you have no gate at all.
#
# IT BLOCKS ONCE. Exit 2 on Stop makes Claude continue the turn, and the message goes to
# stderr, which is what Claude reads. When Claude stops again the input carries
# stop_hook_active: true, and the hook lets it stop (see the hooks events reference).
set -u
IN=$(cat 2>/dev/null || true)
[ -z "$IN" ] && exit 0

# Second stop after this hook already blocked: let Claude stop cleanly.
printf '%s' "$IN" | grep -qE '"stop_hook_active"[[:space:]]*:[[:space:]]*true' && exit 0

# Prefer the finished turn itself (last_assistant_message, needs jq); else the transcript tail.
TAIL=""
if command -v jq >/dev/null 2>&1; then
  TAIL=$(printf '%s' "$IN" | jq -r '.last_assistant_message // empty' 2>/dev/null || true)
fi
if [ -z "$TAIL" ]; then
  TRANSCRIPT=$(printf '%s' "$IN" | sed -n 's/.*"transcript_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  { [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; } && exit 0
  # last 200 lines is the finished turn plus a little context
  TAIL=$(tail -200 "$TRANSCRIPT" 2>/dev/null) || exit 0
fi

CLAIM='(all set|everything works|is (now )?(complete|working|done|fixed)|successfully (built|fixed|implemented)|ready to (ship|merge))'
printf '%s' "$TAIL" | grep -qiE "$CLAIM" || exit 0

# An OBJECT is a named thing a reader could open: a path, a test id, a command, a URL.
OBJECT='([A-Za-z0-9_./-]+\.(py|ts|js|tsx|go|rs|rb|java|sh|md|json|ya?ml)|test_[A-Za-z0-9_]+|::[A-Za-z0-9_]+|https?://[^ ")]+|`[^`]{6,}`)'
# A GENERIC token is a passing signal that names nothing.
GENERIC='(exit(ed)? 0|[0-9]+ passed|all tests pass|tests? pass(ed|ing)?|build (succeeded|ok)|✓|PASS\b)'

HAS_OBJECT=$(printf '%s' "$TAIL" | grep -cE "$OBJECT" || true)
HAS_GENERIC=$(printf '%s' "$TAIL" | grep -ciE "$GENERIC" || true)

if [ "${HAS_GENERIC:-0}" -gt 0 ] && [ "${HAS_OBJECT:-0}" -eq 0 ]; then
  cat >&2 <<'MSG'
DONE-CLAIM GATE

This turn claims the work is finished and the only support in it is a generic passing
token. Nothing names the object that was completed.

A generic pass would read the same if the work had not been done. Before finishing,
add one of: the test that now passes by name, the file and line that changed, the
command that was run with its output, or the URL that now serves the new state.

If the claim is already supported and this gate is wrong, say so and continue. It is
advisory, and a gate that is wrong twice should be deleted rather than worked around.
MSG
  exit 2
fi
exit 0
