#!/usr/bin/env bash
# cnf-check.sh — make a my.cnf bind mount trustworthy; sourced, not run.
# Usage: source "${BASH_SOURCE[0]%/*}/cnf-check.sh"
#
# mariadbd (uid 999) silently skips an option file it cannot read, so a
# 0600 file from a umask-077 shell made an invalid config "valid" and made
# one-off servers run with defaults. Hence:
#   cnf_copy <src> <dst>     0644 copy to bind-mount (my.cnf is not secret)
#   cnf_expected <file>      the file's server options as my_print_defaults
#                            prints them (--key=value), one per line
#   CNF_READ_CHECK           bash code for `docker run ... bash -c` that
#                            fails closed unless my_print_defaults --mysqld,
#                            run as the mysql user, lists every option in
#                            $EXPECTED; then execs its arguments.

cnf_copy() { install -m 0644 "$1" "$2"; }

# Options of the groups my_print_defaults --mysqld reads.
cnf_expected() {
	awk '
		/^[[:space:]]*([#;]|$)/ { next }
		/^[[:space:]]*\[/ {
			g = $0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", g)
			on = (g ~ /^(mysqld|server|mariadb|mariadbd|client-server|galera)(-.*)?$/)
			next
		}
		on {
			line = $0; gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
			n = index(line, "=")
			if (n == 0) { print "--" line; next }
			k = substr(line, 1, n - 1); v = substr(line, n + 1)
			gsub(/[[:space:]]+$/, "", k); gsub(/^[[:space:]]+/, "", v)
			print "--" k "=" v
		}' "$1"
}

# shellcheck disable=SC2016,SC2034  # expands in the container; used by the sourcing scripts
readonly CNF_READ_CHECK='
	set -euo pipefail
	[[ -n "${EXPECTED:-}" ]] || { echo "[ERROR] read check: no options expected from my.cnf"; exit 3; }
	if [[ "$(id -u)" == 0 ]]; then
		mpd=$(gosu mysql my_print_defaults --mysqld) || { echo "[ERROR] read check: my_print_defaults failed"; exit 3; }
	else
		mpd=$(my_print_defaults --mysqld) || { echo "[ERROR] read check: my_print_defaults failed"; exit 3; }
	fi
	missing=0
	while IFS= read -r o; do
		[[ -n "${o}" ]] || continue
		if ! grep -Fxq -- "${o}" <<< "${mpd}"; then
			echo "[ERROR] read check: my.cnf not read, missing ${o}"
			missing=1
		fi
	done <<< "${EXPECTED}"
	(( missing == 0 )) || exit 3
	mapfile -t opts <<< "${EXPECTED}"
	echo "[Note] read check OK: ${opts[*]}"
	exec "$@"'
