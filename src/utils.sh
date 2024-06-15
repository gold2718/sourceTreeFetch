## Utility functions

tbl_gen_hash_key=(61 59 53 47 43 41 37 31 29 23 17 13 11 7 3 1)
tbl_gen_len=${#tbl_gen_hash_key}
gen_hash_key_offset=21467

file_hash() {
    ## Given a full pathname to a file, create a uniqe hash
    local chr
    local chrs
    local hash
    local -i hind
    local -i hval
    local -i val
    if [ -n "$(which xshasum)" ]; then
        hash=$(echo "${1}" | shasum | cut -d' ' -f1)
    else
        hval=${gen_hash_key_offset}
        hind=0
        chrs=($(echo "${1}" | xxd -c 1 | cut -d' ' -f2))
        for chr in ${chrs[@]}; do
            val=$(printf %d "0x${chr}")
            hval=$((hval ^ (val * tbl_gen_hash_key[${hind}])))
            hind=$((hind + 1))
            if [ ${hind} -ge ${tbl_gen_len} ]; then
                hind=0
            fi
        done
        hash="$(printf %x ${hval})"
    fi
    echo "${hash}"
}
