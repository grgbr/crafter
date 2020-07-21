#!/bin/bash -e

# Simply log a message to stderr
log()
{
	echo -e "$(basename $0): $*" >&2
}

# Log a parsing error message to stderr and exit with error status.
log_parse_err()
{
	local prefix="$1"
	local msg="$2"

	log "$prefix parsing failed at line $lnno: $msg\n  \"$line\""

	exit 1
}

check_argc()
{
	local prefix="$1"
	local argc=$2
	local required=$3

	if [ $argc -ne $required ]; then
		log_parse_err "$prefix" "invalid number of arguments"
	fi
}

check_src_path()
{
	local prefix="$1"
	local src_path="$2"

	if [ ! -r "${in_dir}${src_path}" ]; then
		log_parse_err "$prefix" "source path not found (or not readable)"
	fi
}

check_perms()
{
	local prefix="$1"
	local mode="$2"
	local uid="$3"
	local gid="$3"

	if ! echo "$mode" | grep --extended-regexp --quiet '^[0-7]{3,4}$'; then
		log_parse_err "$prefix" "invalid permission mode"
	fi
	if ! echo "$uid" | grep --extended-regexp --quiet '^[0-9]{1,5}$'; then
		log_parse_err "$prefix" "invalid permission user id"
	fi
	if ! echo "$gid" | grep --extended-regexp --quiet '^[0-9]{1,5}$'; then
		log_parse_err "$prefix" "invalid permission group id"
	fi
}

check_dev()
{
	local kind="$1"
	local major="$2"
	local minor="$3"

	if [ "$kind" != "b" ] && [ "$kind" != "c" ]; then
		log_parse_err "device" "invalid device type"
	fi
	if ! echo "$major" | grep --extended-regexp --quiet '^[0-9]+$'; then
		log_parse_err "device" "invalid major device number"
	fi
	if ! echo "$minor" | grep --extended-regexp --quiet '^[0-9]+$'; then
		log_parse_err "device" "invalid minor device number"
	fi
}

gen_log()
{
	local tag="$1"
	local entry="$2"

	if [ $quiet -eq 0 ]; then
		echo "echo \"$tag $entry\" >&2"
	fi
}

# Return command to create file entry under output directory.
make_file_cmd()
{
	local dst_path="$1"
	local src_path="$2"
	local mode="$3"
	local owner="$4"
	local group="$5"

	check_argc "file" $# 5
	check_src_path "file" "$src_path"
	check_perms "file" "$mode" "$owner" "$group"

	gen_log "file" "${out_dir}${dst_path}"
	echo "install --owner=$owner" \
	             "--group=$group" \
	             "--mode=$mode" \
	             "\"${in_dir}${src_path}\"" \
	             "\"${out_dir}${dst_path}\""
}

# Return command to create directory entry under output directory.
make_dir_cmd()
{
	local dst_path="$1"
	local mode="$2"
	local owner="$3"
	local group="$4"

	check_argc "directory" $# 4
	check_perms "directory" "$mode" "$owner" "$group"

	gen_log "dir " "${out_dir}${dst_path}"
	echo "install --owner=$owner" \
	             "--group=$group" \
	             "--mode=$mode" \
	             "-d \"${out_dir}${dst_path}\""
}

# Return command to create device node entry under output directory.
make_dev_cmd()
{
	local dst_path="$1"
	local mode="$2"
	local owner="$3"
	local group="$4"
	local kind="$5"
	local major="$6"
	local minor="$7"

	check_argc "device" $# 7
	check_perms "device" "$mode" "$owner" "$group"
	check_dev "$kind" "$major" "$minor"

	gen_log "node" "${out_dir}${dst_path}"
	echo "mknod --mode=$mode" \
	           "\"${out_dir}${dst_path}\"" \
	           "$kind" \
	           "$major" \
	           "$minor;" \
	     "chown -h $owner:$group \"${out_dir}${dst_path}\""
}

# Return command to create symbolic link entry under output directory.
make_slink_cmd()
{
	local dst_path="$1"
	local target_path="$2"
	local owner="$3"
	local group="$4"

	check_argc "symlink" $# 4
	check_perms "symlink" "777" "$owner" "$group"

	gen_log "link" "${out_dir}${dst_path}"
	echo "ln -sf \"$target_path\" \"${out_dir}${dst_path}\";" \
	     "chown -h $owner:$group \"${out_dir}${dst_path}\""
}

# Return command to create named pipe (fifo) entry under output directory.
make_pipe_cmd()
{
	local dst_path="$1"
	local mode="$2"
	local owner="$3"
	local group="$4"

	check_argc "pipe" $# 4
	check_perms "pipe" "$mode" "$owner" "$group"

	gen_log "fifo" "${out_dir}${dst_path}"
	echo "[ -e \"${out_dir}${dst_path}\" ] && rm \"${out_dir}${dst_path}\";" \
	     "mkfifo --mode=$mode \"${out_dir}${dst_path}\";" \
	     "chown -h $owner:$group \"${out_dir}${dst_path}\""
}

# Parse and output command(s) refering to a specification file line of input
parse_spec_line()
{
	local ftype="$1"

	shift 1

	case $ftype in
	file)  make_file_cmd $*;;
	dir)   make_dir_cmd $*;;
	nod)   make_dev_cmd $*;;
	slink) make_slink_cmd $*;;
	pipe)  make_pipe_cmd $*;;
	*)     log_parse_err "entry type" "invalid entry type";;
	esac
}

# Parse and output commands refering to a complete specification file.
gen_cmd_list()
{
	local lnno=1
	local spec_file="$1"
	local line

	# For each line of input...
	cat $spec_file | while read line; do
		if ! echo "$line" | grep --quiet '^#.*'; then
			# Not a comment line: parse and output command according
			# to current line specification
			local cmd=$(parse_spec_line $line)
			if [ -z "$cmd" ]; then
				exit 1
			fi

			echo "$cmd"
		fi

		# Maintain a line counter to ouput meaningful error messages.
		lnno=$((lnno + 1))
	done
}

# Show help
usage() {
	local ret=$1

	cat >&2 <<_EOF
Usage: $(basename $0) [OPTIONS] <OUT_DIR> <IN_DIR> [SPEC_FILE]

Generate directory hierarchy from an input root directory according to a
specification file describing entries to be included.
Entries will be generated according to file system properties defined into the
given file system specification file, optionally wrapping operations into a
fakeroot environment to overcome permission issues when not running as root
user.

With OPTIONS:
  -q|--quiet                -- enable silent operations
  -e|--exec                 -- generate file system entries into OUT_DIR (by
                               default, $(basename $0) only outputs commands
                               that would be executed when running with the
                               --exec option)
  -f|--fake <FAKE_ENV_FILE> -- wrap operations within fakeroot using the
                               specified environment file FAKE_ENV_FILE
                               (implies --exec)

Where:
  IN_DIR                    -- pathname to root of input directory hierarchy to
                               build OUT_DIR from
  OUT_DIR                   -- pathname to root of output directory hierarchy to
                               generate content into
  SPEC_FILE                 -- pathname to file system specification file
                               defining entries to be included in the final
                               output directory hierarchy
  FAKE_ENV_FILE             -- pathname to environment file to provide fakeroot

Environment variable:
  FAKEROOT                  -- pathname to fakeroot binary
                               (defaults to fakeroot)

SPEC_FILE syntax
----------------
File system specification file contains newline separated entries that describe
the files to be included into the final OUT_DIR hierarchy. Comments are
filtered out.

Syntax must follow rules depicted below :
  comment        #
  file           file <name> <location> <mode> <uid> <gid>
  directory      dir <name> <mode> <uid> <gid>
  device node    nod <name> <mode> <uid> <gid> <dev_type> <maj> <min>
  symbolic link  slink <name> <target> <mode> <uid> <gid>
  pipe           pipe <name> <mode> <uid> <gid>

Where :
  <name>         name of the file/dir/nod/etc in the output directory hierarchy
  <location>     location of the file in the input directory hierarchy
  <target>       link target
  <mode>         output filesystem entry octal mode/permissions
  <uid>          output filesystem entry user id
  <gid>          output filesystem entry group id
  <dev_type>     output filesystem device node type (b=block, c=character)
  <maj>          output filesystem device node major number
  <min>          output filesystem device node minor number

Example :
  # A simple example
  dir /    755 0 0
  dir /dev 755 0 0
  nod /dev/console 600 0 0 c 5 1
  dir /sbin 755 0 0
  file /sbin/kinit /usr/src/klibc/kinit/kinit 755 0 0
  dir /tmp 1777 0 0
  pipe /tmp/fifo 600 0 0
  dir /var 755 0 0
  slink /var/tmp /tmp 0 0
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
               --options ef:qh \
               --longoptions exec,fake:,quiet,help \
               -- "$@"); then
	# Something went wrong, getopt will put out an error message for us
	echo
	usage 1
fi
# Replace command line with getopt parsed output
eval set -- "$options"
# Process command line option arguments now that it has been sanitized by getopt
exec_cmd=0
quiet=0
spec_file='-'
while [ $# -gt 0 ]; do
	case $1 in
	-e|--exec)  exec_cmd=1;;
	-f|--fake)  exec_cmd=1; fake_env="$2"; shift 1;;
	-q|--quiet) quiet=1;;
	-h|--help)  usage 0;;
	--)         shift 1; break;;
	-*)         log "unrecognized option \"$1\""; usage 1;;
	*)          break;;
	esac

	shift 1
done

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
	log "invalid number of arguments\n"
	usage 1
fi

# Check that given output directory is valid. Also ensure proper pathname
# canonicalization to prevent from interfering with specification file path
# concatenation logic (no trailing slashes expected).
#
# Note: if last path compoment does not exist it will be created provided the
# specification file defines a proper root directory entry.
if ! out_dir="$(readlink --canonicalize $1)"; then
	log "invalid \"$1\" output root directory:" \
	    "all but the last path component must exist"
	exit 1
fi
if [ -e "$out_dir" ]; then
	if [ ! -d "$out_dir" ]; then
		log "invalid \"$1\" output root directory: not a directory"
		exit 1
	fi
else
	if [ ! -d "$(dirname $out_dir)" ]; then
		log "invalid \"$1\" output root directory: not a directory"
		exit 1
	fi
fi

# Check that given input directory is valid. Also ensure proper pathname
# canonicalization to prevent from interfering with specification file path
# concatenation logic (no trailing slashes expected).
if ! in_dir="$(readlink --canonicalize-existing $2)"; then
	log "invalid \"$2\" input root directory:" \
	    "all path components must exist"
	exit 1
fi
if [ ! -d "$in_dir" ]; then
	log "invalid \"$2\" input root directory: not a directory"
	exit 1
fi

# Check that specification file is valid. stdin is allowed and shall be passed
# on command line as "-" pathname.
if [ $# -eq 3 ]; then
	spec_file="$3"
	if [ "$spec_file" != "-" ] && [ ! -r "$spec_file" ]; then
		log "invalid \"$spec_file\" specification file"
		exit 1
	fi
fi

if [ $exec_cmd -gt 0 ]; then
	# Compute the list of commands to run to generate the requested output
	# directory hierarchy.
	cmd_list="$(gen_cmd_list $spec_file)"

	# If requested, prepare the fakeroot wrapper invocation.
	fake_cmd=""
	if [ -n "$fake_env" ]; then
		fake_cmd="exec ${FAKEROOT:=fakeroot} -s $fake_env"
		if [ -e "$fake_env" ]; then
			fake_cmd="$fake_cmd -i $fake_env"
		fi
		fake_cmd="$fake_cmd -- "
	fi

	# Execute the list of commands computed above.
	$fake_cmd sh -c "$cmd_list"
else
	# Output a list of commands that would be performed if the --exec option
	# was passed on the command line.
	quiet=1
	gen_cmd_list "$spec_file"
fi
