#! /usr/bin/env bash

set -eo pipefail

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
  { echo>&2 "ERROR: $0 cannot find $f"; exit 1; }; f=; set -e
# --- end runfiles.bash initialization v3 ---


set -u

source "$(rlocation fshlib/log.bash)"

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
- name: "upload-shar"
  type: string
  help: "The shar archive to upload to remote server for programming"
- name: "binary"
  type: string
  help: "The programmer daemon binary to start"
- name: "prog-server"
  type: string
  help: "The programming server name, either actual, or as in ~/.ssh.config"
- name: "uploaded-program-name"
  type: string
  default: "serial_upload.bash"
  help: "The name of the uploaded program"
- name: "debug"
  type: bool
  default: false
  help: "If set, debug diagnosis is turned on"
- name: "remote-timeout"
  type: string
  default: "3600"
  help: "Hard timeout (seconds) for the REMOTE serial_upload; guarantees the serial port frees itself even if the local side dies (ssh -t HUP does not reliably kill it -- orphans held /dev/ttyUSB0 repeatedly)"
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

readonly _remote_timeout="${gotopt2_remote_timeout}"

rsync --copy-links "${_prog}" "${_remote}:~/${_uploaded}" 2>&1 | log::prefix "[upload] "
# timeout(1) on the remote guarantees the serial port is released even when
# the local side is killed (--linger otherwise leaves an orphaned holder).
ssh -t "${_remote}" \
  timeout --signal=TERM --kill-after=10 "${_remote_timeout}" \
  "./${_uploaded}" ${gotopt2_args__[@]} 2>&1

# vim: set ft=bash :
