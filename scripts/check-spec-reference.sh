#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

. ./.conventions

BASE_REF=${1:?usage: check-spec-reference.sh <base-ref> <pull-request-body-file>}
BODY_FILE=${2:?usage: check-spec-reference.sh <base-ref> <pull-request-body-file>}

CHANGED_GUARDED_FILES=""
for GUARDED_PATH in $SPEC_REQUIRED_PATHS; do
	CHANGED_GUARDED_FILES="$CHANGED_GUARDED_FILES$(git diff --name-only "$BASE_REF"...HEAD -- "$GUARDED_PATH")"
done

if [ -z "$CHANGED_GUARDED_FILES" ]; then
	echo "No changes under: $SPEC_REQUIRED_PATHS"
	exit 0
fi

REFERENCED_SPECS=$(grep -oE "$SPECS_DIRECTORY/[0-9]{3}-[a-z0-9-]+" "$BODY_FILE" | sort -u || true)

if [ -z "$REFERENCED_SPECS" ]; then
	echo "This pull request changes files under: $SPEC_REQUIRED_PATHS; its description must name a $SPECS_DIRECTORY/NNN-name folder" >&2
	exit 1
fi

MISSING=0
for SPEC in $REFERENCED_SPECS; do
	if [ -f "$SPEC/spec.md" ]; then
		echo "Spec found: $SPEC/spec.md"
	else
		echo "Referenced spec does not exist in this branch: $SPEC/spec.md" >&2
		MISSING=$((MISSING + 1))
	fi
done

if [ "$MISSING" -gt 0 ]; then
	exit 1
fi

echo "Spec reference check passed"
