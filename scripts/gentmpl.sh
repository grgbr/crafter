#!/bin/sh -e

. "$(realpath $(dirname $0))/wrap_cheetah.sh"

$(getPythonCheetah) "$(realpath $(dirname $0))/gentmpl.py" "$@"