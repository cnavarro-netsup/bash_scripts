#!/usr/bin/env bash

set -euo pipefail

SCRIPT_SOURCE="${BASH_SOURCE[0]}"
if [[ "${SCRIPT_SOURCE}" == */* ]]; then
    SCRIPT_DIR="$(cd "${SCRIPT_SOURCE%/*}" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi

INPUT_FILE="${SCRIPT_DIR}/datos.txt"
OUTPUT_FILE="${SCRIPT_DIR}/datos.png"
TEMP_DATA_FILE="$(mktemp)"

cleanup()
{
    rm -f "${TEMP_DATA_FILE}"
}

trap cleanup EXIT INT TERM

print_error()
{
    printf 'Error: %s\n' "$1" >&2
}

validate_environment()
{
    if ! command -v gnuplot >/dev/null 2>&1; then
        print_error "gnuplot is not installed or not available in PATH."
        exit 1
    fi

    if [ ! -f "${INPUT_FILE}" ]; then
        print_error "Input file not found: ${INPUT_FILE}."
        exit 1
    fi

    if [ ! -r "${INPUT_FILE}" ]; then
        print_error "Input file is not readable: ${INPUT_FILE}."
        exit 1
    fi
}

prepare_plot_data()
{
    local bucket=""
    local value=""
    local extra=""
    local plot_value=""
    local line_count=0

    : > "${TEMP_DATA_FILE}"

    while IFS=' ' read -r bucket value extra; do
        if [ -z "${bucket}${value}${extra}" ]; then
            continue
        fi

        if [ -n "${extra}" ]; then
            print_error "Invalid input line: expected exactly two columns."
            exit 1
        fi

        if [ -z "${bucket}" ]; then
            print_error "Invalid input line: bucket is empty."
            exit 1
        fi

        if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
            print_error "Invalid input line: value must be a non-negative integer."
            exit 1
        fi

        if [ "${value}" -eq 0 ]; then
            plot_value="0.1"
        else
            plot_value="${value}"
        fi

        printf '%s %s\n' "${bucket}" "${plot_value}" >> "${TEMP_DATA_FILE}"
        line_count=$((line_count + 1))
    done < "${INPUT_FILE}"

    if [ "${line_count}" -eq 0 ]; then
        print_error "Input file is empty: ${INPUT_FILE}."
        exit 1
    fi
}

render_plot()
{
    gnuplot <<EOF
set terminal pngcairo size 1400,800
set output '${OUTPUT_FILE}'
set title 'Mail Size Distribution'
set xlabel 'Size bucket (MB)'
set ylabel 'Mail count'
set logscale y
set yrange [0.1:*]
set grid ytics
set key off
set style fill solid 0.85 border rgb '#1e3a8a'
set boxwidth 0.7 relative
set tics out
set xtics rotate by -35
plot '${TEMP_DATA_FILE}' using 2:xtic(1) with boxes lc rgb '#60a5fa'
EOF
}

main()
{
    validate_environment
    prepare_plot_data
    render_plot
    printf 'Plot written to %s\n' "${OUTPUT_FILE}"
}

main
