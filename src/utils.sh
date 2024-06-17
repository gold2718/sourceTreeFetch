## Error codes
CFG_INTERNAL_ERR=11
CFG_SYNTAX_ERROR=12
CFG_EXTNAME_ERROR=13
CFG_KEYWORD_ERROR=14
CFG_INVALID_CHAR=15

## Special separator characters, not allowed in configuration file
## While this could technically show up in a directory name, does anyone use it?
SECTION_CHR='&'
KEYVAL_CHR='@'
NAME_CHR=';'
SPECIAL_CHRS="${SECTION_CHR}|${NAME_CHR}|${KEYVAL_CHR}"

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

strip_arg() {
    ## Simply strip the leading and trailing whitespace around the
    ## input arguments. Note, multiple internal spaces converted to a
    ## single space
    echo $@
}

parse_keyword() {
    ## Parse a line that looks like 'keyword = value' and return the keyword
    local key="$(strip_arg $(echo ${@} | cut -d'=' -f1))"
    echo "${key}"
}

parse_value() {
    ## Parse a line that looks like 'keyword = value' and return the value
    local val="$(strip_arg $(echo ${@} | cut -s -d'=' -f2))"
    echo "${val}"
}

valid_string() {
    ## Check to see if string ($1) has any invalid character
    ## $2 is a regex to detect any invalid character or sequence
    if [[ "${1}" =~ ${2} ]]; then
        return ${CFG_INVALID_CHAR}
    else
        return 0
    fi
}
