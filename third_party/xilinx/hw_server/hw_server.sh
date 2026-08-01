#!/usr/bin/env bash

readonly SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ROOT_DIR="."
if [[ "${RUNFILES_DIR}" != "" ]]; then
  ROOT_DIR="${RUNFILES_DIR}/_main"
fi

source "${ROOT_DIR}/third_party/shlib/log.sh"

log_info "Running in script dir: ${SCRIPT_DIR}"
ps axw | grep ld.so | grep -v ld.so | prefix_line "[processes] "
log_info "Killing ld.so"
killall ld.so 2>&1 | prefix_line "[killall] "

readonly _timeout="60"

set -eo pipefail
/usr/bin/env ld.so \
		--library-path $SCRIPT_DIR/lib \
		"${SCRIPT_DIR}/bin/hw_server" \
		-stcp::3121 \
		-I "${_timeout}" \
		-L- -l jtag -l jtag2 \
		-l events -l slave -l proxy \
		${@} | prefix_line "[xilinx:hw_server] "

# vim: set ft=bash :
