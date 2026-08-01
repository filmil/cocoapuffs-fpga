function log_info() {
    local _green="\033[32m"
    local _normal="\033[0m"
    echo -e "${_green}INFO:${_normal} ${@}"
}

function log_warn() {
    local _green="\033[33m"
    local _normal="\033[0m"
    echo -e "${_green}WARN:${_normal} ${@}"
}

function log_error() {
    local _green="\033[31m"
    local _normal="\033[0m"
    echo -e "${_green}ERROR:${_normal} ${@}"
}

function prefix_line() {
  local _prefix="${1:-}"
  sed "s/^/$_prefix/"
}
