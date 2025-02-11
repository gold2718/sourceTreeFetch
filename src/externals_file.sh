#! /bin/bash

## Parse an Externals.cfg file into an internal format and provide routines
## to provide useful information as requested.

script_dir="$(cd $(dirname ${0}); pwd -P)"
if [ -f "${script_dir}/utils.sh" ]; then
    . "${script_dir}/utils.sh"
else
    echo "Cannot find utils.sh"
    exit 1
fi

## What are the allowed keywords in an Externals.cfg section?
declare -A EXTERNAL_KEYWORDS=(["branch"]=1 ["externals"]=1 ["from_submodule"]=1 \
                              ["hash"]=1 ["local_path"]=1 ["protocol"]=1        \
                              ["repo_url"]=1 ["required"]=1 ["sparse"]=1 ["tag"]=1)

CFG_DESC_NAME="externals_description"
VERSION_KEY="schema_version"
CFG_FILENAME_KEY="xxCfgFilePath"
SECTION_REGEX='\[[[:space:]]*([-A-Za-z0-9_]+)[[:space:]]*]'

declare externals=() # Collection of external names of parsed externals config file

cfgerr() {
    ## On an error condition ($1 != 0), print an error message and quit
    ## $1 is the status (zero or an error code)
    ## $2 is the current config line number
    ## $3 is the current config filename
    ## $4 is the cumulative error string
    ## $5 is an error message
    local estr=""
    if [ ${1} -ne 0 ]; then
        if [ -n "${4}" ]; then
            estr="${4}\nERROR: ${5} on ${3}:${2}"
        else
            estr="ERROR: ${5} on ${3}:${2}"
        fi
    fi
    echo "${estr}"
}

cfg_to_externals() {
    ## Convert an internal configuration format $2 to externals
    ## Add each external to the input $1.
    local sections=(${2//${SECTION_CHR}/ })
    local val
    local version

    for section in ${sections[@]}; do
        tmparr=(${section//${NAME_CHR}/ })
        eval "${1}[\${tmparr[0]}]=\${tmparr[1]}"
    done
}

# 1. create externals_list as a module variable (list of external names)
# 2. declare and export an assoc array for an external being parsed
# 3. write accessor functions for external name list and external assoc array
# 4. does it work?
parse_externals_cfg_file() {
    ## Given a file, parse an externals file into an internal format
    local config=""       # The parsed configuration
    local current_ext=""  # The name of the current external being parsed
    local inline          # Current line minus leading and trailing whitespace
    local key
    local line            # Current line being parsed
    local -i lineno=0        # Current line number
    local res
    local -i num_errors=0
    local tmp
    local value
    local version=""      # The configuration file schema version
    local errstr=""       # Cumulative error string

    if [ ! -f "${1}" ]; then
        errstr="Cannot find file, '${1}'"
        num_errors=$((num_errors + 1))
        echo "${errstr}"
        return ${num_errors}
    fi
    while read line; do
        lineno=$((lineno + 1))
        inline="$(echo ${line} | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
        inline="$(strip_arg ${line})"
        if [ ${#inline} -eq 0 ]; then
            # Blank line, ignore
            continue
        elif [ "${inline:0:1}" == "#" ]; then
            # Comment, ignore
            continue
        elif [[ "${inline}" =~ ${SECTION_REGEX} ]]; then
            current_ext="${BASH_REMATCH[1]}"
            valid_string "${current_ext}" "${SPECIAL_CHRS}"
            res=$?
            if [ ${res} -ne 0 ]; then
                errstr=$(cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} "${errstr}"    \
                                "Invalid char in external name, '${current_ext}'")
                num_errors=$((num_errors + 1))
            fi
            tmp="$(printf '%s\n' ${externals[@]} | grep -F -x ${current_ext})"
            if [ -n  "${tmp}" ]; then
                errstr=$(cfgerr ${CFG_EXTNAME_ERROR} ${lineno} ${1} "${errstr}"  \
                                "Duplicate external name, ${current_ext},")
                num_errors=$((num_errors + 1))
            elif [ "${current_ext}" != "${CFG_DESC_NAME}" ]; then
                externals+=(${current_ext})
                export externals
                export -n ${current_ext}
                eval "declare -g -A ${current_ext}"
                export -n ${current_ext}
            fi # No else, special case handled in keyword section
        elif [ -n "$(echo ${inline} | grep '=')" ]; then
            key="$(parse_keyword ${inline})"
            val="$(parse_value ${inline})"
            if [ -z "${current_ext}" ]; then
                errstr=$(cfgerr ${CFG_SYNTAX_ERROR} ${lineno} ${1} "${errstr}" \
                                "Invalid keyword line, not parsing a section")
                num_errors=$((num_errors + 1))
            elif [ "${current_ext}" == "${CFG_DESC_NAME}" ]; then
                if [ "${key}" == "${VERSION_KEY}" ]; then
                    valid_string "${val}" "${SPECIAL_CHRS}"
                    res=$?
                    if [ ${res} -eq 0 ]; then
                        version="${val}"
                    else
                        errstr=$(cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1}         \
                                        "${errstr}" "Invalid character in '${val}'")
                        num_errors=$((num_errors + 1))
                    fi
                else
                    tmp="Invalid keyword, '${key}'"
                    errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1}          \
                                    "${errstr}"                                  \
                                    "${tmp}, in ${CFG_DESC_NAME} section")
                    num_errors=$((num_errors + 1))
                fi
            elif [[ -v EXTERNAL_KEYWORDS[${key}] ]]; then
                valid_string "${val}" "${SPECIAL_CHRS}"
                res=$?
                if [ ${res} -eq 0 ]; then
                    eval "${current_ext}[${key}]=\"${val}\""
#                    tmp="${key}${KEYVAL_SEP}${val}"
#                    if [ -n "${externals[${current_ext}]}" ]; then
#                        tmp="${externals[${current_ext}]}${KEYVAL_CHR}${tmp}"
#                    fi
#                    externals[${current_ext}]="${tmp}"
                else
                    errstr=$(cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} "${errstr}" \
                                    "Invalid character in '${val}'")
                    num_errors=$((num_errors + 1))
                fi
            else
                tmp="Invalid keyword, '${key}'"
                errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} "${errstr}"   \
                                "${tmp}, in ${current_ext} section")
                num_errors=$((num_errors + 1))
            fi
        else
            errstr=$(cfgerr ${CFG_SYNTAX_ERROR} ${lineno} ${1}        \
                            "${errstr}" "Syntax error")
            num_errors=$((num_errors + 1))
        fi
    done < "${1}"
#    # Wrapup
#    config="${CFG_DESC_NAME}${NAME_CHR}${CFG_FILENAME_KEY}${KEYVAL_SEP}${1}"
#    config="${config}${KEYVAL_CHR}${VERSION_KEY}${KEYVAL_SEP}${version}"
#    line="$(echo ${!externals[@]} | sort)"
#    for key in ${line}; do
#        config="${config}${SECTION_CHR}${key}${NAME_CHR}${externals[${key}]}"
#    done
    if [ ${num_errors} -eq 1 ]; then
        echo "${errstr}"
    elif [ ${num_errors} -gt 0 ]; then
        echo -e "${num_errors} errors found\n${errstr}"
    else
        echo "${externals[@]}"
    fi
    return ${num_errors}
}

externals_list() {
    # Return the list of externals when a config file has been parsed
    echo "${externals[@]}"
}

external_keywords() {
    # Given an external name ($1), return a list of its configuration keywords
    if [[ -v "${1}" ]]; then
        eval "echo \${!${1}[@]}"
    else
        echo "${1} not found: ${#cam[@]}"
    fi
}

print_externals_cfg() {
    ## Pretty print an externals configuration ($1)
    local -A externals=()
    local file
    local key
    local keyval
    local section
    local sections
    local val
    local version

    cfg_to_externals externals "${1}"
    for section in $(echo ${!externals[@]} | tr ' ' '\n' | sort); do
        if [ "${section}" != "${CFG_DESC_NAME}" ]; then
            echo "[${section}]"
        fi
        for keyval in ${externals[${section}]//${KEYVAL_CHR}/ }; do
            key=$(echo ${keyval} | cut -d"${KEYVAL_SEP}" -f1)
            val=$(echo ${keyval} | cut -d"${KEYVAL_SEP}" -f2-)
            if [ "${section}" == "${CFG_DESC_NAME}" ]; then
                if [ "${key}" == "${VERSION_KEY}" ]; then
                    version="${val}"
                fi
            else
                echo "  ${key} = ${val}"
            fi
        done
        echo ""
    done
    echo "[${CFG_DESC_NAME}]"
    echo "  ${VERSION_KEY} = ${version}"
}
