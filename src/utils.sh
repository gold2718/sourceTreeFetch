## Error codes
CFG_INTERNAL_ERR=11
CFG_SYNTAX_ERROR=12
CFG_EXTNAME_ERROR=13
CFG_KEYWORD_ERROR=14
CFG_INVALID_CHAR=15
CFG_MISSING_FILE=16
CFG_DUPLICATE_TYPE=17
CFG_DUPLICATE_KEY=18
CFG_UNSUPPORTED=19
CFG_MISSING_PATH=20

## Global strings and numbers
POSITIONAL_KEY="$(echo '*' | md5sum | cut -d' ' -f1)"
export INDENT=24             # Description indent for help lines
export LINELEN=80            # Output line length

## Regular expressions for various parts of a config file
EXTERNAL_REGEX="[A-Za-z][A-Za-z0-9_]*" # For an external name
VERSION_REGEX="[1-9][0-9]*[.][0-9]*[.][0-9]*"

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
    ## Check to see if string ($1) matches a regular expression ($2)
    if ! [[ "${1}" =~ ${2} ]]; then
        return ${CFG_INVALID_CHAR}
    else
        return 0
    fi
}

bool_to_string() {
    ## Given a boolean value ($1), return True of False
    ## If $2 and $3 are present, return $2 for True and $3 for False
    if ${1}; then
        if [ $# -gt 1 ]; then
            echo "${2}"
        else
            echo "True"
        fi
    else
        if [ $# -gt 2 ]; then
            echo "${3}"
        else
            echo "False"
        fi
    fi
}

check_file() {
    # Check that a file ($2) exists or output an error and exit
    if [ ! -f "${2}" ]; then
        echo "ERROR: ${1}, '${2}', not found"
        exit ${CFG_MISSING_FILE}
    fi
}

check_path() {
    # Check that a path ($2) exists or output an error and exit
    if [ ! -d "${2}" ]; then
        echo "ERROR: ${1}, '${2}', not found"
        exit ${CFG_MISSING_PATH}
    fi
}

format_line() {
    ## Given a descriptor ($1) and a description ($2), format the output
    local ind_str="$(printf ' %.0s' $(seq 1 ${INDENT}))"
    local line="${1}"
    local desc="${2}"
    local -i curr_col
    local -i desc_ind=0
    local -i desc_len=${#desc}
    local -i last_space=0
    if [ ${#line} -le $((INDENT - 4)) ]; then # 4 is an arbitrary space choice
        line="${line}${ind_str}"
        line="${line:0:INDENT}"
    else
        echo -e "${line}"
        line="${ind_str}"
    fi
    curr_col=${INDENT}
    while [ ${desc_ind} -lt ${desc_len} ]; do
        if [ "${desc:${desc_ind}:1}" == " " ]; then
            last_space=${curr_col}
        fi
        line="${line}${desc:${desc_ind}:1}"
        curr_col=$((curr_col + 1))
        desc_ind=$((desc_ind + 1))
        if [ ${curr_col} -ge ${LINELEN} ]; then
            # Back up to the last space
            echo -e "${line:0:${last_space}}"
            desc_ind=$((desc_ind - curr_col + last_space + 1))
            line="${ind_str}"
            curr_col=${#line}
            last_space=0
        elif [ ${desc_ind} -ge ${desc_len} ]; then
            echo "${line}"
        fi
    done
}

help() {
    # Given a description ($1) and a list of help variable entries
    # ($HELP_OPTIONS), Produce a help screen
    # Each help variable entry contains 4 items:
    # 1: Option names (* for positional) separated by a vertical bar
    # 2: Option input hint string (empty string for flags)
    # 3: Option description
    # 4: Option action (not used in help)
    # If there is a positional argument description, it should be first.
    local -i ind
    local -i item_ind
    local printed_options=false
    local printed_positional=false
    local desc
    local hint
    local optname
    echo -e "${1}"
    shift
    for item_ind in $(seq 1 $((${#HELP_OPTIONS[@]} / 4))); do
        ind=$(( (item_ind - 1) * 4 ))
        optname="${HELP_OPTIONS[${ind}]}"
        hint="${HELP_OPTIONS[${ind}+1]}"
        desc="${HELP_OPTIONS[${ind}+2]}"
        if [ "${optname}" == "${POSITIONAL_KEY}" ]; then
            if ! ${printed_positional}; then
                echo -e "\npositional arguments:"
                printed_positional=true
            fi
            format_line "${hint}" "${desc}"
        else
            if ! ${printed_options}; then
                echo -e "\noptions:"
                printed_options=true
            fi
            format_line "${optname} ${hint}" "${desc}"
        fi
    done
}
