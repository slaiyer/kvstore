#!/usr/bin/env bash

set -o errexit
set -o errtrace
set -o nounset
set -o pipefail

PYTHON_VERSION_MIN="${1}"
shift 1
PYTHON_CMDS=("${@}")

for cmd in "${PYTHON_CMDS[@]}"; do
    if ! command -v "${cmd}" >/dev/null; then
        >&2 printf '%s not found\n' "${cmd}"
    elif ! "${cmd}" -c \
            "import sys; \
            cur_ver = sys.version_info[:2]; \
            min_ver = tuple(map(int, '${PYTHON_VERSION_MIN}'.split('.'))); \
            sys.exit(int(not(bool(cur_ver >= min_ver))))" >/dev/null; then
        >&2 printf '%s does not meet minimum Python version requirement: %s\n' \
                "${cmd}" \
                "${PYTHON_VERSION_MIN}"
    else
        printf '%s' "${cmd}"
        exit
    fi
done

exit 1
