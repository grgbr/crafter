#!/bin/bash -e

log_err()
{
	local msg="$1"

	echo "$argv0: $msg." >&2
	exit 1
}

so_name()
{
	local so_path="$1"

	env LC_ALL=C \
	$readelf -d $so_path | \
	sed -n '/(SONAME)[[:blank:]]\+Library soname/s/[^[]\+\[\([^]]\+\)\].*/\1/p'
}

usage() {
	local ret=$1
	local msg="$2"

	if [ -n "$msg" ]; then
		echo "$argv0: $msg." >&2
		echo >&2
	fi

	cat >&2 <<_EOF
Usage: $argv0 [OPTION] <SOFILE>

Display the name of shared library file passed as argument.

With OPTION:
  -h|--help      -- this help message

Where:
  SOFILE -- path to library file to display name for

Environment variable:
  READELF -- pathname to readelf binary (defaults to readelf)
_EOF

	exit $ret
}

# Setup (sub-)shell behavior.
#
# Pipeline return code is the value of the last (rightmost) command to exit with
# a non-zero status.
set -o pipefail
# All sub-shells will inherit the above settings
export SHELLOPTS

argv0="$(basename $0)"

# Check and sanitize command line content
if ! options=$(getopt \
               --name "$argv0" \
               --options h \
               --longoptions help \
               -- "$@"); then
	# Something went wrong, getopt will put out an error message for us
	echo
	usage 1
fi
# Replace command line with getopt parsed output
eval set -- "$options"
# Process command line option arguments now that it has been sanitized by getopt
while [ $# -gt 0 ]; do
	case $1 in
	-h|--help)      usage 0;;
	--)             shift 1; break;;
	-*)             usage 1 "unrecognized option \"$1\"" ;;
	*)              break;;
	esac

	shift 1
done

if [ $# -ne 1 ]; then
	usage 1 "invalid number of argument"
fi

readelf="${READELF:-$(which readelf)}"
if [ ! -x "$readelf" ]; then
	log_err "\"$readelf\": invalid readelf command"
fi

if ! sofile="$(readlink --canonicalize-existing $1)"; then
	log_err "\"$1\": no such library file"
fi

if ! name=$(so_name "$sofile"); then
	log_err "\"$1\": library name not found"
fi

if [ -z "$name" ]; then
	log_err "\"$1\": not a library"
fi

echo "$name"
