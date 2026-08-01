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

source "$(rlocation fshlib+/log.bash)"

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
- name: "upload-shar"
  type: string
  help: "The shar archive to upload to remote server for programming"
- name: "prog-daemon-binary"
  type: string
  help: "The programmer daemon binary to start"
- name: "prog-server"
  type: string
  help: "The programming server name, either actual, or as in ~/.ssh.config"
- name: "uploaded-program-name"
  type: string
  default: "prog.sh"
  help: "The name of the uploaded program"
- name: "remote-port"
  type: int
  default: 3121
  help: "The default port on the remote programmer machine where the hw server runs"
- name: "local-host"
  type: string
  help: "The name of the local host to connect to"
  default: "localhost"
- name: "local-port"
  type: int
  default: 3122
  help: "The default port on this local machine where the hw server is forwarded to"
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

if [[ "${gotopt2_upload_shar}" == "" ]]; then
  log::error "Flag --upload-shar=... is required"
  exit 1
fi
if [[ "${gotopt2_prog_server}" == "" ]]; then
  log::error "Flag --prog-server=... is required"
  exit 1
fi

readonly _prog="${gotopt2_upload_shar}"
readonly _remote="${gotopt2_prog_server}"
readonly _uploaded="${gotopt2_uploaded_program_name}"

log::info Program: "${_prog}"
log::info Remote: "${_remote}"
log::debug Uploaded archive: ${_uploaded}

readonly _local_host="${gotopt2_local_host}"
readonly _remote_port="${gotopt2_remote_port}"
readonly _local_port="${gotopt2_local_port}"

log::info "Local programming server hostport: ${_local_host}:${_local_port}"

rsync --copy-links "${_prog}" "${_remote}:~/${_uploaded}" 2>&1 | log::prefix "[upload] "
ssh -t -L "${_local_port}:${_local_host}:${_remote_port}" \
  "${_remote}" "./${_uploaded}" 2>&1 \
  | log::prefix "[${_remote}] "

# vim: set ft=bash :
