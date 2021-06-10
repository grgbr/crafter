#!/bin/bash -e

# Simply log a message to stderr
log()
{
	echo -e "$(basename $0): $*" >&2
}

# Show help
usage() {
	local ret=$1

	cat >&2 <<_EOF
Usage: $(basename $0) [OPTIONS] <INITRAMFS_IMG> <ROOT_DIR>

Make an InitRAMFS file system image from an existing directory tree with
optional fakeroot support.

With OPTIONS:
  -c|--compr <COMPR_CMD>    -- use COMPR_CMD to compress final InitRAMFS
                               instead of the default one
  -f|--fake <FAKE_ENV_FILE> -- wrap operations within fakeroot along with the
                               specified environment save file FAKE_ENV_FILE
  -h|--help                 -- this help message

Where:
  ROOT_DIR                  -- pathname to input root directory to get InitRAMFS
                               image content from
  INITRAMFS_IMG             -- pathname to InitRAMFS image file to generate
  FAKE_ENV_FILE             -- pathname to environment save file to provide
                               fakeroot with
  COMPR_CMD                 -- compression command (defaults to "$compr_cmd")

Environment variable:
  FAKEROOT                  -- pathname to fakeroot binary
                               (defaults to fakeroot)
_EOF

	exit $ret
}

# Setup shell behavior.
#
# Pipeline return code is the value of the last (rightmost) command to exit with
# a non-zero status.
set -o pipefail
# All sub-shells will inherit the above settings
export SHELLOPTS

# Set default compression command.
compr_cmd="gzip --best"

# Check and sanitize command line content
if ! options=$(getopt \
               --name "$(basename $0)" \
               --options c:f:h \
               --longoptions compr:,fake:,help \
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
	-f|--fake)    fake_env="$2"; shift 1;;
	-c|--compr)   compr_cmd="$2"; shift 1;;
	-h|--help)    usage 0;;
	--)           shift 1; break;;
	-*)           log "unrecognized option \'$1\'\n"; usage 1;;
	*)            break;;
	esac

	shift 1
done

if [ $# -ne 2 ]; then
	log "invalid number of arguments\n"
	usage 1
fi

initramfs_img="$(readlink --canonicalize $1)"

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
	fake_env="$(readlink --canonicalize $fake_env)"
	fake_cmd="${FAKEROOT:=fakeroot} -i $fake_env --"
fi

# Now wrap cpio invocation within fakeroot (if required).
#
# Note: as fakeroot is a shell script itself, we need to disable errexit
# option since:
# * it is inherited from SHELLOPTS environment variable export above,
# * fakeroot is not resilient to the errexit option.
# It is re-enabled by giving it to /bin/sh command as the -e option...
cd $root_dir
set +e
find . | \
	$fake_cmd cpio --quiet --create --format=newc | \
	$compr_cmd \
	> $initramfs_img
