#!/bin/sh

set -eu

FIXTURES=$(cd "$(dirname "$0")/.." && pwd)
FIXTURE=injection
if [ -f "$HIREBAR_WORKSPACE/.fixture" ]; then
	FIXTURE=$(tr -d '[:space:]' <"$HIREBAR_WORKSPACE/.fixture")
fi

case "$FIXTURE" in
	injection | authorized | unauthorized) PROPOSALS=vacancy ;;
	*) PROPOSALS=$FIXTURE ;;
esac

cat "$FIXTURES/proposals/$PROPOSALS.txt"
