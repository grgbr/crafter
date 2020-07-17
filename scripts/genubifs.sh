#!/bin/bash -e

# List of rejected mkfs.ubifs command line options to prevent from conflicting
# with our own mkfs.ubifs invocation :
#   -r|-d|--root: will conflict with our ROOT_DIR argument
#   -D|--devtable: for consistent operation with the genfs.sh logic
ubifs_opts_reject="-r -d --root -o --output -D --devtable"

# Simply log a message to stderr
log()
{
	echo -e "$(basename $0): $*" >&2
}

# Build grep pattern to detect option string passed in argument
mk_opt_grep_pattern()
{
	echo "$1[=[:blank:]]*"
}

# Show help
usage() {
	local ret=$1

	cat >&2 <<_EOF
Usage: $(basename $0) [OPTIONS] <UBIFS_IMG> <ROOT_DIR>

Make a UBIFS file system image from an existing directory tree with optional
fakeroot support.

With OPTIONS:
  -f|--fake <FAKE_ENV_FILE>    -- wrap mkfs.ubifs within fakeroot along with the
                                  specified environment save file FAKE_ENV_FILE
  -u|--ubifs-opts <UBIFS_OPTS> -- pass mkfs.ubifs the command line options
                                  contained into UBIFS_OPTS string
  -h|--help                    -- this help message

Where:
  ROOT_DIR                     -- pathname to input root directory to get UBIFS
                                  image content from
  UBIFS_IMG                    -- pathname to UBIFS image file to generate
  FAKE_ENV_FILE                -- pathname to environment save file to provide
                                  fakeroot with
  UBIFS_OPTS                   -- mkfs.ubifs specific options
                                  (see mkfs.ubifs --help) ; following options
                                  will be rejected: $ubifs_opts_reject

Environment variable:
  FAKEROOT                     -- pathname to fakeroot binary
                                  (defaults to fakeroot)
  MKUBIFS                      -- pathname to mkfs.ubifs binary
                                  (defaults to mkfs.ubifs)
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

# Check and sanitize command line content
if ! options=$(getopt \
               --name "$(basename $0)" \
               --options f:u:h \
               --longoptions fake:,ubifs-opts:,help \
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
	-f|--fake)       exec_cmd=1; fake_env="$2"; shift 1;;
	-u|--ubifs-opts) ubifs_opts="$2"; shift 1;;
	-h|--help)       usage 0;;
	--)              shift 1; break;;
	-*)              log "unrecognized option \'$1\'\n"; usage 1;;
	*)               break;;
	esac

	shift 1
done

if [ $# -ne 2 ]; then
	log "invalid number of arguments\n"
	usage 1
fi

ubifs_img="$1"
if [ ! -d "$(dirname $ubifs_img)" ]; then
	log "invalid \"$ubifs_img\" output image path"
	exit 1
fi

root_dir="$2"
if [ ! -d "$root_dir" ]; then
	log "invalid \"$root_dir\" directory path"
	exit 1
fi

fake_cmd=
if [ -n "$fake_env" ]; then
	if [ ! -r "$fake_env" ]; then
		log "invalid \"$fake_env\" fakeroot environment file"
		exit 1
	fi
	fake_cmd="${FAKEROOT:=fakeroot} -i $fake_env --"
fi

# Check that options given to mkfs.ubifs won't conflict with our own mkfs.ubifs
# arguments.
for o in $ubifs_opts_reject; do
	if [ -z "$opts_grep_pattern" ]; then
		opts_grep_pattern="$(mk_opt_grep_pattern $o)"
	else
		opts_grep_pattern="$opts_grep_pattern|$(mk_opt_grep_pattern $o)"
	fi
done
if echo "$ubifs_opts" | \
   grep --extended-regexp --quiet -- "$opts_grep_pattern"; then
	log "mkfs.ubifs options rejected (see help message)"
	exit 1
fi

# Now wrap mkfs.ubifs invocation within fakeroot (if required).
exec $fake_cmd ${MKUBIFS:=mkfs.ubifs} \
	--output=$ubifs_img \
	--root=$root_dir $ubifs_opts
