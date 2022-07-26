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
Usage: $(basename $0) [OPTIONS] <TEMPLATE> <MODULE_NAME>
Generate templated crafter module.

With OPTIONS:
  -o|--outdir <MODULES_DIR> -- Directory where create templated file.
  -p|--python <PYTHON>      -- Set python path. Force not use PYTHON env.

Where:
  TEMPLATE                  -- Template name.
  MODULE_NAME               -- Module name used in name and as prefix variable
                               in template. "-" and " " are forbiden char.
  MODULES_DIR               -- Pathname to output dir to write makefile.
  PYTHON                    -- Pathname to python with cheetah.

Templates:
  autotools                 -- Project make with autotools.
  base                      -- Base template less specific commands.
  cmake                     -- Project make with cmake.
  ebuild                    -- Project make with ebuild.
  fakefs                    -- Base fake root file system.
  kbuild                    -- Project make with kbuild.
  meson                     -- Project make with meson.
_EOF

	exit $ret
}

# Check and sanitize command line content
if ! options=$(getopt \
               --name "$(basename $0)" \
               --options o:p:h \
               --longoptions outdir:,python:,help \
               -- "$@"); then
	# Something went wrong, getopt will put out an error message for us
	echo
	usage 1
fi
# Replace command line with getopt parsed output
eval set -- "$options"
# Process command line option arguments now that it has been sanitized by getopt
outdir='.'
while [ $# -gt 0 ]; do
	case $1 in
	-o|--outdir)  outdir="$2"; shift 1;;
  -p|--python)  PYTHON="$2"; shift 1;;
	-h|--help)    usage 0;;
	--)           shift 1; break;;
	-*)           log "unrecognized option \"$1\""; usage 1;;
	*)            break;;
	esac

	shift 1
done

if [ $# -ne 2 ]; then
	log "invalid number of arguments\n"
	usage 1
fi

template="$1"
module="$2"
outdir=$(realpath $outdir)
templatedir="$(realpath $(dirname $0)/../template)"
scriptsdir="$(realpath $(dirname $0))"

. ${scriptsdir}/wrap_cheetah.sh

if [ ! -d "$outdir" ]; then
	log "invalid \"$outdir\" directory"
	exit 1
fi

if [ ! -f "${templatedir}/${template}.mk.in" ]; then
        log "invalid \"$template\" template"
        exit 1
fi
template="${templatedir}/${template}.mk.in"

case "$module" in
  *"-"*|*" "*) log "Forbiden char in module name \"$module\""; exit 1;;
esac

if [ -z "$PYTHON" ]; then
        PYTHON=$(getPythonCheetah)
fi

if ! $PYTHON -c 'import Cheetah' 2> /dev/null; then
        log "package Cheetah not found in \"$PYTHON\""
fi

log "GENTMPL ${outdir}/${module}.mk"
exec $PYTHON ${scriptsdir}/gentmpl.py --output "${outdir}/${module}.mk" "${template}" MODULE=${module}