#! /usr/bin/env bash
set -eo pipefail

readonly _binary_path="rules_multitool++multitool+multitool/tools/gotopt2/gotopt2"

ROOT_DIR="."
if [[ "${RUNFILES_DIR}" != "" ]]; then
  ROOT_DIR="${RUNFILES_DIR}/_main"
fi


# --- begin runfiles.bash initialization ---
# Copy-pasted from Bazel's Bash runfiles library (tools/bash/runfiles/runfiles.bash).
if [[ ! -d "${RUNFILES_DIR:-/dev/null}" && ! -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  if [[ -f "$0.runfiles_manifest" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles_manifest"
  elif [[ -f "$0.runfiles/MANIFEST" ]]; then
    export RUNFILES_MANIFEST_FILE="$0.runfiles/MANIFEST"
  elif [[ -f "$0.runfiles/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
    export RUNFILES_DIR="$0.runfiles"
  fi
fi
if [[ -f "${RUNFILES_DIR:-/dev/null}/bazel_tools/tools/bash/runfiles/runfiles.bash" ]]; then
  source "${RUNFILES_DIR}/bazel_tools/tools/bash/runfiles/runfiles.bash"
elif [[ -f "${RUNFILES_MANIFEST_FILE:-/dev/null}" ]]; then
  source "$(grep -m1 "^bazel_tools/tools/bash/runfiles/runfiles.bash " \
            "$RUNFILES_MANIFEST_FILE" | cut -d ' ' -f 2-)"
else
  echo >&2 "ERROR: cannot find @bazel_tools//tools/bash/runfiles:runfiles.bash"
  exit 1
fi
# --- end runfiles.bash initialization ---
set -u

_fshlib_location="$(rlocation fshlib+/log.bash)"
if [[ "${_fshlib_location}" == "" ]]; then
  _fshlib_location="$(rlocation fshlib~/log.bash)"
  if [[ "${_fshlib_location}" == "" ]]; then
    echo>&2 "ERROR: cannot find fshlib/log.bash"
    exit 1
  fi
fi
source "${_fshlib_location}"
log::debug "Current dir: $PWD"

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
  log::error "gotopt2 binary not found"
  exit 240
fi

GOTOPT2_OUTPUT=$($_gotopt2_binary "${@}" <<EOF
flags:
- name: "daemon-binary"
  type: string
  help: "The binary to use to start the device programming"
- name: "prog-server"
  type: string
  help: "The programming server host"
EOF
)
if [[ "$?" == "11" ]]; then
  # When --help option is used, gotopt2 exits with code 11.
  exit 0
fi

# Evaluate the output of the call to gotopt2, shell vars assignment is here.
eval "${GOTOPT2_OUTPUT}"

_upload_binary="$(rlocation _main/third_party/xilinx/hw_server/upload.bash)"
if [[ "${_upload_binary}" == "" ]]; then
  log::error "Upload binary not found"
  exit 1
fi
log::debug "Upload binary: ${_upload_binary}"

_daemon_binary="${gotopt2_daemon_binary}"
if [[ "${_daemon_binary}" == "" ]]; then
  log::error "Daemon binary not found"
  exit 1
fi
log::debug "Daemon binary: ${_daemon_binary}"
log::debug "Other args: ${gotopt2_args__[@]}"

# Forwarding this to `log::info` removes a lot of verbosity, if things break,
# doublecheck here to be sure nothing is going sideways.
"${_daemon_binary}" ${gotopt2_args__[@]} 2>&1 \
  | log::prefix "[$(basename ${_daemon_binary})] "

# vim: set ft=bash :
