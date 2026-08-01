#! /usr/bin/env bash

readonly SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

ROOT_DIR="."
if [[ "${RUNFILES_DIR}" != "" ]]; then
  ROOT_DIR="${RUNFILES_DIR}/_main"
fi

# --- begin runfiles.bash initialization v3 ---
# Copy-pasted from the Bazel Bash runfiles library v3.
set -uo pipefail; set +e; f=bazel_tools/tools/bash/runfiles/runfiles.bash
# shellcheck disable=SC1090
source "${RUNFILES_DIR:-/dev/null}/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "${RUNFILES_MANIFEST_FILE:-/dev/null}" | cut -f2- -d' ')" 2>/dev/null || \
  source "$0.runfiles/$f" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  source "$(grep -sm1 "^$f " "$0.exe.runfiles_manifest" | cut -f2- -d' ')" 2>/dev/null || \
  {
    f_fallback="_main/third_party/futility/runfiles.bash"
    source "${RUNFILES_DIR:-/dev/null}/$f_fallback" 2>/dev/null || \
    source "$0.runfiles/$f_fallback" 2>/dev/null || \
    { echo>&2 "ERROR: $0 cannot find $f"; exit 1; }
  }; f=; set -e
# --- end runfiles.bash initialization v3 ---


source "$(rlocation fshlib+/log.bash)"

readonly _binary_path="rules_multitool++multitool+multitool/tools/gotopt2/gotopt2"

# This is somewhat of a hack: we're trying to find the runfiles path of a binary
# whose location is with respect to its position in the dependency repo. So,
# strip 'external/' where it applies.
if [[ "${_binary_path}" == "external/"* ]]; then
    _binary_path="${_binary_path#external/}"
fi
readonly _gotopt2_binary="$(rlocation ${_binary_path})"


# Exit quickly if the binary isn't found. This may happen if the binary location
# moves internally in bazel.
if [[ ! -x "${_gotopt2_binary}" ]]; then
  echo "gotopt2 binary not found"
  exit 240
fi

GOTOPT2_OUTPUT=$($_gotopt2_binary "${@}" <<EOF
flags:
- name: "binary"
  type: string
  help: "The binary to start"
- name: "debug"
  type: bool
  default: false
  help: "If set, debug diagnosis is turned on"
EOF
)
if [[ "$?" == "11" ]]; then
  # When --help option is used, gotopt2 exits with code 11.
  exit 0
fi

# Evaluate the output of the call to gotopt2, shell vars assignment is here.
eval "${GOTOPT2_OUTPUT}"

if [[ "${gotopt2_debug}" == "true" ]]; then
  log::warn "Debugging turned on."
  env | log::prefix "[debug:env] "
  echo "${GOTOPT2_OUTPUT}" | log::prefix "[debug:flags] "
  set -x
fi

log::debug "Running in script dir: ${SCRIPT_DIR}"

readonly _serial_upload_bin="../rules_multitool++multitool+multitool/tools/serial_upload/serial_upload"
log::debug "binary: ${_serial_upload_bin}"

"${_serial_upload_bin}" ${gotopt2_args__[@]}

# vim: set ft=bash :
