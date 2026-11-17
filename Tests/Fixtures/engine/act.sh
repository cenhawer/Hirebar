#!/bin/sh

set -eu

FIXTURE=authorized
if [ -f "$HIREBAR_WORKSPACE/.fixture" ]; then
	FIXTURE=$(tr -d '[:space:]' <"$HIREBAR_WORKSPACE/.fixture")
fi

BATCH=$(printf '%s\n' "$HIREBAR_PROMPT" | sed -n 's/.*"batch": "\([^"]*\)".*/\1/p' | head -n 1)
FIRST_ITEM=$(printf '%s\n' "$HIREBAR_PROMPT" | sed -n 's/^- itemId: \([^ ]*\) [^ ]* action: \([^ ]*\) [^ ]* target: \(.*\)$/\1|\2|\3/p' | head -n 1)
ITEM_ID=${FIRST_ITEM%%|*}
REMAINING=${FIRST_ITEM#*|}
ACTION=${REMAINING%%|*}
TARGET=${REMAINING#*|}

if [ "$FIXTURE" = unauthorized ]; then
	ITEM_ID=not-approved
fi

mkdir -p "$HIREBAR_WORKSPACE/ejecuciones"
printf '{"schemaVersion": 1, "batch": "%s", "actions": [{"itemId": "%s", "action": "%s", "target": %s, "outcome": "done", "at": "%s"}]}\n' \
	"$BATCH" "$ITEM_ID" "$ACTION" "$TARGET" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$HIREBAR_WORKSPACE/ejecuciones/$BATCH.acciones.json"

echo "Fixture $FIXTURE: registré una acción sobre $ITEM_ID"
