#!/bin/sh

set -eu
cd "$(dirname "$0")/.."

. ./.conventions

BASE_REF=${1:?usage: check-conventions.sh <base-ref> [branch-name]}
BRANCH_NAME=${2:-$(git rev-parse --abbrev-ref HEAD)}
FAILURES=0

as_alternation() {
	echo "$1" | tr ' ' '|'
}

COMMIT_PATTERN="^($(as_alternation "$COMMIT_TYPES"))(\([a-z0-9-]+\))?!?: [a-z0-9].*[^.]$"
BRANCH_WITH_TICKET_PATTERN="^($(as_alternation "$BRANCH_TYPES_WITH_TICKET"))/${TICKET_PREFIX}-[0-9]+(-[a-z0-9]+)+$"
BRANCH_WITHOUT_TICKET_PATTERN="^($(as_alternation "$BRANCH_TYPES_WITHOUT_TICKET"))/[a-z0-9]+(-[a-z0-9]+)*$"
RELEASE_PATTERN='^release/[0-9]+\.[0-9]+\.[0-9]+$'

if ! echo "$BRANCH_NAME" | grep -Eq "$BRANCH_WITH_TICKET_PATTERN|$BRANCH_WITHOUT_TICKET_PATTERN|$RELEASE_PATTERN"; then
	echo "Invalid branch name: $BRANCH_NAME (expected {type}/${TICKET_PREFIX}-{number}-{description})" >&2
	FAILURES=$((FAILURES + 1))
fi

for COMMIT in $(git rev-list --no-merges "$BASE_REF"..HEAD); do
	SUBJECT=$(git log -1 --format=%s "$COMMIT")
	DESCRIPTION=${SUBJECT#*: }
	if ! echo "$SUBJECT" | grep -Eq "$COMMIT_PATTERN"; then
		echo "Invalid commit $COMMIT: $SUBJECT" >&2
		FAILURES=$((FAILURES + 1))
	elif [ "${#DESCRIPTION}" -gt "$DESCRIPTION_MAX_LENGTH" ]; then
		echo "Commit description longer than $DESCRIPTION_MAX_LENGTH characters $COMMIT: $SUBJECT" >&2
		FAILURES=$((FAILURES + 1))
	fi
done

if [ "$FAILURES" -gt 0 ]; then
	echo "Conventions check failed: $FAILURES problem(s)" >&2
	exit 1
fi

echo "Conventions check passed"
