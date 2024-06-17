#! /bin/bash

## Parse an Externals.cfg file into an internal format and provide routines
## to provide useful information as requested.

if [ -f "/utils.sh" ]; then
    . utils.sh
elif [ -f "src/utils.sh" ]; then
    . src/utils.sh
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
SECTION_REGEX='\[[[:space:]]*([-A-Za-z0-9_]+)[[:space:]]*]'

cfgerr() {
    ## On an error condition ($1 != 0), print an error message and quit
    ## $1 is the status (zero or an error code)
    ## $2 is the current config line number
    ## $3 is the current config filename
    ## $4 is an error message
    if [ ${1} -ne 0 ]; then
        echo "ERROR: ${4} on ${3}:${2}"
    fi
    return ${1}
}

parse_externals_cfg_file() {
    ## Given a file, parse an externals file into an internal format
    local config=""       # The parsed configuration
    local current_ext=""  # The name of the current external being parsed
    local -A externals=() # For collecting externals during parsing
    local inline          # Current line minus leading and trailing whitespace
    local key
    local line            # Current line being parsed
    local lineno=0        # Current line number
    local res
    local tmp
    local value
    local version=""      # The configuration file schema version

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
                cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} \
                       "Invalid character in external name, '${current_ext}'"
            fi
            if [[ -v externals[${current_ext}] ]]; then
                cfgerr ${CFG_EXTNAME_ERROR} ${lineno} ${1} \
                       "Duplicate external name, ${current_ext}"
            elif [ "${current_ext}" != "${CFG_DESC_NAME}" ]; then
                externals[${current_ext}]=""
            fi # No else, special case handled in keyword section
        elif [ -n "$(echo ${inline} | grep '=')" ]; then
            key="$(parse_keyword ${inline})"
            val="$(parse_value ${inline})"
            if [ -z "${current_ext}" ]; then
                cfgerr ${CFG_SYNTAX_ERROR} ${lineno} ${1} \
                       "Invalid keyword line, not parsing a section"
            elif [ "${current_ext}" == "${CFG_DESC_NAME}" ]; then
                if [ "${key}" == "${VERSION_KEY}" ]; then
                    valid_string "${val}" "${SPECIAL_CHRS}"
                    res=$?
                    if [ ${res} -eq 0 ]; then
                        version="${val}"
                    else
                        cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} \
                               "Invalid character in '${val}'"
                    fi
                else
                    cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} \
                           "Invalid keyword, '${key}', in ${CFG_DESC_NAME} section"
                fi
            elif [[ -v EXTERNAL_KEYWORDS[${key}] ]]; then
                valid_string "${val}" "${SPECIAL_CHRS}"
                res=$?
                if [ ${res} -eq 0 ]; then
                    tmp="${externals[${current_ext}]}${KEYVAL_CHR}${key}:${val}"
                    externals[${current_ext}]="${tmp}"
                else
                    cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} \
                           "Invalid character in '${val}'"
                fi
            else
                cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} \
                       "Invalid keyword, '${key}', in ${current_ext} section"
            fi
        else
            cfgerr ${CFG_SYNTAX_ERROR} ${lineno} ${1} "Syntax error"
        fi
    done < "${1}"
    # Wrapup
    config="${1}${SECTION_CHR}${version}"
    line="$(echo ${!externals[@]} | sort)"
    for key in ${line}; do
        config="${config}${SECTION_CHR}${key}${NAME_CHR}${externals[${key}]}"
    done
    echo "${config}"
}

print_externals_cfg() {
    ## Pretty print an externals configuration ($1)
    local -A externals=()
    local file
    local key
    local keyval
    local section
    local sections=(${1//${SECTION_CHR}/ })
    local val
    local version

    file="${sections[0]}"
    version="${sections[1]}"
    for section in ${sections[@]:2}; do
        tmparr=(${section//${NAME_CHR}/ })
        externals[${tmparr[0]}]=${tmparr[1]}
    done
    for section in $(echo ${!externals[@]} | tr ' ' '\n' | sort); do
        echo "[${section}]"
        for keyval in ${externals[${section}]//${KEYVAL_CHR}/ }; do
            key=$(echo ${keyval} | cut -d':' -f1)
            val=$(echo ${keyval} | cut -d':' -f2-)
            echo "  ${key} = ${val}"
        done
        echo ""
    done
    echo "[${CFG_DESC_NAME}]"
    echo "  ${VERSION_KEY} = ${version}"
}
