#!/usr/bin/env bash

mkdir -p output/rtl
mkdir -p output/ref
for i in $(seq "${2}"); do
    ref_out="output/ref/${i}_forward.txt"
    rtl_out="output/rtl/${i}_forward.txt"
    ./four-step-NTT.elf 7 < "testcase/${i}.txt" > "${ref_out}"
    cp "testcase/${i}.hex" /tmp/tmp.hex
    "./${1}" > "${rtl_out}"

    if ! diff "${ref_out}" <(head -n 128 "${rtl_out}") > /dev/null 2>&1; then
        exit 1
    fi

    ref_out="output/ref/${i}_inv.txt"
    rtl_out="output/rtl/${i}_inv.txt"
    ./four-step-NTT.elf 7 inv < "testcase/${i}.txt" > "${ref_out}"
    cp "testcase/${i}.hex" /tmp/tmp.hex
    "./${1}" +inv > "${rtl_out}"

    if ! diff "${ref_out}" <(head -n 128 "${rtl_out}") > /dev/null 2>&1; then
        exit 1
    fi
done

tput setaf 2
echo "AC"
tput sgr0
