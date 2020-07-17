#!/bin/bash -e

# List of rejected mksquashfs command line options to prevent from conflicting
# with our own mksquashfs invocation :
#   -r|-d|--root: will conflict with our ROOT_DIR argument
#   -D|--devtable: for consistent operation with the genfs.sh logic
squashfs_opts_reject="-noappend -no-progress"

# Simply log a message to stderr
log()
{
	echo -e "$(basename $0): $*" >&2
}

# Build grep pattern to detect long option string passed in argument
mk_opt_grep_pattern()
{
	echo "$1[=[:blank:]]*"
}

# Show help
usage() {
	local ret=$1

	cat >&2 <<_EOF
Usage: $(basename $0) [OPTIONS] <SQUASHFS_IMG> <ROOT_DIR>

Make a SquashFS file system image from an existing directory tree with optional
fakeroot support.

With OPTIONS:
  -f|--fake <FAKE_ENV_FILE>          -- wrap mksquashfs within fakeroot along
                                        with the specified environment save file
                                        FAKE_ENV_FILE
  -s|--squashfs-opts <SQUASHFS_OPTS> -- pass mksquashfs the command line options
                                        contained into SQUASHFS_OPTS string
  -h|--help                          -- this help message

Where:
  ROOT_DIR                           -- pathname to input root directory to get
                                        SquashFS image content from
  SQUASHFS_IMG                       -- pathname to SquashFS image file to
                                        generate
  FAKE_ENV_FILE                      -- pathname to environment save file to
                                        provide fakeroot with
  SQUASHFS_OPTS                      -- mksquashfs specific options
                                        (see mksquashfs --help) ; following
                                        options will be rejected:
                                        $squashfs_opts_reject

Environment variable:
  FAKEROOT                           -- pathname to fakeroot binary
                                        (defaults to fakeroot)
  MKSQUASHFS                         -- pathname to mksquashfs binary
                                        (defaults to mksquashfs)
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
               --options f:s:h \
               --longoptions fake:,squashfs-opts:,help \
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
	-f|--fake)          exec_cmd=1; fake_env="$2"; shift 1;;
	-s|--squashfs-opts) squashfs_opts="$2"; shift 1;;
	-h|--help)          usage 0;;
	--)                 shift 1; break;;
	-*)                 log "unrecognized option \'$1\'\n"; usage 1;;
	*)                  break;;
	esac

	shift 1
done

if [ $# -ne 2 ]; then
	log "invalid number of arguments\n"
	usage 1
fi

squashfs_img="$1"

root_dir="$2"
if [ ! -d "$root_dir" ]; then
	log "invalid \"$root_dir\" directory"
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

# Check that options given to mksquashfs won't conflict with our own mksquashfs
# arguments.
for o in $squashfs_opts_reject; do
	if [ -z "$opts_grep_pattern" ]; then
		opts_grep_pattern="$(mk_opt_grep_pattern $o)"
	else
		opts_grep_pattern="$opts_grep_pattern|$(mk_opt_grep_pattern $o)"
	fi
done
if echo "$squashfs_opts" | \
   grep --extended-regexp --quiet -- "$opts_grep_pattern"; then
	log "mksquashfs options rejected (see help message)"
	exit 1
fi

# Now wrap mksquashfs invocation within fakeroot (if required).
exec $fake_cmd ${MKSQUASHFS:=mksquashfs} \
	$root_dir \
	$squashfs_img \
	-noappend -no-progress $squashfs_opts >/dev/null
