#!/usr/bin/env bash
inv=""
if [ "${3:-}" == "inv" ]; then
    echo "set to inv"
    inv="inv"
fi

mkdir -p output/rtl
mkdir -p output/ref
for i in $(seq "${2}"); do
    ref_out="output/ref/${i}_forward.txt"
    rtl_out="output/rtl/${i}_forward.txt"
    ./four-step-NTT.elf 7 < "testcase/${i}.txt" > "${ref_out}"
    cp "testcase/${i}.hex" /tmp/tmp.hex
    "./${1}" > "${rtl_out}"

    ref_out="output/ref/${i}_inv.txt"
    rtl_out="output/rtl/${i}_inv.txt"
    ./four-step-NTT.elf 7 inv < "testcase/${i}.txt" > "${ref_out}"
    cp "testcase/${i}.hex" /tmp/tmp.hex
    "./${1}" +inv > "${rtl_out}"
done
