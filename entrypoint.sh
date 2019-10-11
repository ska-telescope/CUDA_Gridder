#!/usr/bin/env bash
set -Eeo pipefail
# TODO swap to -Eeuo pipefail above (after handling all potentially-unset variables)

# kickoff
if [ "$1" = 'gridder' ]; then
	# launch app
	cd /app
	exec ./gridder "$@"
fi

exec "$@"
