#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

BASE_REF=${1:-}
REPORT=$(mktemp)
CHANGED_LINES=$(mktemp)
trap 'rm -f "$REPORT" "$CHANGED_LINES"' EXIT

for TOOL in swift swiftlint; do
	if ! command -v "$TOOL" >/dev/null 2>&1; then
		echo "$TOOL is not installed" >&2
		exit 1
	fi
done

if [ -n "$BASE_REF" ]; then
	SWIFT_FILES=$(git diff --name-only --diff-filter=ACMR "$BASE_REF"...HEAD -- '*.swift')
	git diff -U0 --diff-filter=ACMR "$BASE_REF"...HEAD -- '*.swift' | awk '
		/^\+\+\+ b\// { file = substr($0, 7) }
		/^@@/ {
			split($3, range, ",")
			start = substr(range[1], 2)
			count = (range[2] == "") ? 1 : range[2]
			for (line = start; line < start + count; line++) print file ":" line
		}' >"$CHANGED_LINES"
else
	SWIFT_FILES=$(git ls-files '*.swift')
fi

if [ -z "$SWIFT_FILES" ]; then
	echo "No Swift files to lint"
	exit 0
fi

{
	echo "$SWIFT_FILES" | xargs swift format lint --configuration .swift-format 2>&1 || true
	echo "$SWIFT_FILES" | xargs swiftlint lint --quiet --reporter xcode 2>/dev/null || true
} | sed "s|^$PWD/||" | grep -E '^[^:]+:[0-9]+:[0-9]+: (warning|error):' >"$REPORT" || true

if [ -n "$BASE_REF" ]; then
	VIOLATIONS=$(awk -F: 'NR == FNR { changed[$1 ":" $2] = 1; next } ($1 ":" $2) in changed' "$CHANGED_LINES" "$REPORT")
else
	VIOLATIONS=$(cat "$REPORT")
fi

if [ -n "$VIOLATIONS" ]; then
	echo "$VIOLATIONS"
	echo "Lint failed: $(echo "$VIOLATIONS" | wc -l | tr -d ' ') violation(s) in changed lines" >&2
	exit 1
fi

echo "Lint passed"
