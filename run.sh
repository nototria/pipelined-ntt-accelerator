#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./run.sh [dit|dif] [input_hex_file] [cycles]
#   ./run.sh [dit|dif] [cycles]

mode="${1:-dit}"
case "${mode}" in
    dit|dif) ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        echo "Invalid mode: ${mode}" >&2
        usage
        exit 1
        ;;
esac
shift || true

input=""
cycles=""

if [ $# -ge 1 ]; then
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        cycles="$1"
        shift
    else
        input="$1"
        shift
        if [ $# -ge 1 ]; then
            cycles="$1"
            shift
        fi
    fi
fi

if [ $# -ne 0 ]; then
    usage
    exit 1
fi

if [ -n "${input}" ] && [ ! -f "${input}" ]; then
    echo "Input file not found: ${input}" >&2
    exit 1
fi

if [ -n "${cycles}" ] && [[ ! "${cycles}" =~ ^[0-9]+$ ]]; then
    echo "cycles must be a positive integer." >&2
    exit 1
fi

make run MODE="${mode}" INPUT="${input}" CYCLES="${cycles}"
