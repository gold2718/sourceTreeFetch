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
                              ["hash"]=1 ["local_path"]=1 ["repo_url"]=1        \
                              ["required"]=1 ["sparse"]=1 ["tag"]=1)

CFG_DESC_NAME="externals_description"
VERSION_KEY="schema_version"
SECTION_REGEX='\[[[:space:]]*([-A-Za-z0-9_]+)[[:space:]]*]'

export UNSET_STR="_UNSET_" # Standard string to indicate a missing required value
export NONE_STR="_NONE_"   # Standard string to indicate an unset optional value

declare externals=() # Collection of external names of parsed externals config file
# Required elements
declare -A ext_co_type     # Checkout type (branch, hash, tag) of external
declare -A ext_co_loc      # Commit (branch name, hash, tag) to checkout
declare -A ext_local_path  # Relative path for external checkout
declare -A ext_repo_url    # URL of external upstream repo
# Optional elements
declare -A ext_externals   # Path of external's sub-external file (relative to ext)
                           # Default is ${NONE_STR}
declare -A ext_required    # Flag set to 1 of external is required
                           # Default is required
declare -A ext_sparse_file # Sparse checkout file path (relative to <local_path>)
                           # Default is full checkout

# Variables used for parsing
curr_ext=""             # The name of the current external being parsed
inline=""               # Current line minus leading and trailing whitespace
key=""
line=""                 # Current line being parsed
declare -i lineno=0     # Current line number
declare -i res=0        # Command result
declare -i num_errors=0 # Total number of errors found
tmp=""
val=""

# Information about the parsed file
externals_filename=""   # The name of the parsed externals file
version=""              # The configuration file schema version
errstr=""               # Cumulative error string

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

found_errors() {
    # Return 0 if errors were found parsing the externals file, 1 otherwise
    if [ -n "${errstr}" ]; then
        return 0
    else
        return 1
    fi
}


report_errors() {
    if [ -n "${errstr}" ]; then
        echo -e "${errstr}"
    fi
}

check_missing_keywords() {
    # Check for any missing required keywords for the external, ($1)
    local ext="${1}"
    if [ "${ext_co_type[${ext}]}" == "${UNSET_STR}" ]; then
        errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} "${errstr}" \
                        "${ext} missing the 'tag', 'hash', or 'branch' keyword")
        num_errors=$((num_errors + 1))
    fi
    if [ "${ext_co_loc[${ext}]}" == "${UNSET_STR}" ]; then
        errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} "${errstr}" \
                        "${ext} missing a commit name")
        num_errors=$((num_errors + 1))
    fi
    if [ "${ext_local_path[${ext}]}" == "${UNSET_STR}" ]; then
        errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} "${errstr}" \
                        "${ext} missing the 'local_path' keyword")
        num_errors=$((num_errors + 1))
    fi
    if [ "${ext_repo_url[${ext}]}" == "${UNSET_STR}" ]; then
        errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} "${errstr}" \
                        "${ext} missing 'repo_url' keyword")
        num_errors=$((num_errors + 1))
    fi
}

externals_list() {
    # Return the list of externals when a config file has been parsed
    echo "${externals[@]}"
}

external_checkout_type() {
    # Given an external name ($1), return the type of checkout (branch, hash, tag)
    if [[ -v ext_co_type[${1}] ]]; then
        echo "${ext_co_type[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

external_checkout_loc() {
    # Given an external name ($1), return the commit to checkout
    if [[ -v ext_co_loc[${1}] ]]; then
        echo "${ext_co_loc[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

external_local_path() {
    # Given an external name ($1), return its local path
    if [[ -v ext_local_path[${1}] ]]; then
        echo "${ext_local_path[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

external_repo_url() {
    # Given an external name ($1), return the URL for its upstream repository
    if [[ -v ext_repo_url[${1}] ]]; then
        echo "${ext_repo_url[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

external_externals() {
    # Given an external name ($1), return its sub-externals file (or NONE_STR)
    if [[ -v ext_externals[${1}] ]]; then
        echo "${ext_externals[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

external_required() {
    # Given an external name ($1), return a 1 if the external is required
    if [[ -v ext_required[${1}] ]]; then
        echo "${ext_required[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

external_sparse() {
    # Given an external name ($1), return the sparse checkout filename (or NONE_STR)
    if [[ -v ext_sparse_file[${1}] ]]; then
        echo "${ext_sparse_file[${1}]}"
    else
        echo "External ${1} not found"
    fi
}

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
        if [ -n "${curr_ext}" -a "${curr_ext}" != "${CFG_DESC_NAME}" ]; then
            ## Check the external we just parsed
            check_missing_keywords "${curr_ext}"
        fi
        curr_ext="${BASH_REMATCH[1]}"
        valid_string "${curr_ext}" "${EXTERNAL_REGEX}"
        res=$?
        if [ ${res} -ne 0 ]; then
            errstr=$(cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} "${errstr}"    \
                            "Invalid char in external name, '${curr_ext}'")
            num_errors=$((num_errors + 1))
        fi
        tmp="$(printf '%s\n' ${externals[@]} | grep -F -x ${curr_ext})"
        if [ -n  "${tmp}" ]; then
            errstr=$(cfgerr ${CFG_EXTNAME_ERROR} ${lineno} ${1} "${errstr}"  \
                            "Duplicate external name, ${curr_ext},")
            num_errors=$((num_errors + 1))
        elif [ "${curr_ext}" != "${CFG_DESC_NAME}" ]; then
            # Record a new external
            externals+=(${curr_ext})
            # Set up the new external's variables
            ext_co_type[${curr_ext}]=${UNSET_STR}
            ext_co_loc[${curr_ext}]=${UNSET_STR}
            ext_local_path[${curr_ext}]=${UNSET_STR}
            ext_repo_url[${curr_ext}]=${UNSET_STR}
            ext_externals[${curr_ext}]=${NONE_STR}
            ext_required[${curr_ext}]=1
            ext_sparse_file[${curr_ext}]=${NONE_STR}
        fi # No else, special case handled in keyword section
    elif [ -n "$(echo ${inline} | grep '=')" ]; then
        key="$(parse_keyword ${inline})"
        val="$(parse_value ${inline})"
        if [ -z "${curr_ext}" ]; then
            errstr=$(cfgerr ${CFG_SYNTAX_ERROR} ${lineno} ${1} "${errstr}" \
                            "Invalid keyword line, not parsing a section")
            num_errors=$((num_errors + 1))
        elif [ "${curr_ext}" == "${CFG_DESC_NAME}" ]; then
            if [ "${key}" == "${VERSION_KEY}" ]; then
                valid_string "${val}" "${VERSION_REGEX}"
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
            res=$?
            if [ ${res} -eq 0 ]; then
                case ${key} in
                    branch)
                        if [ "${ext_co_type[${curr_ext}]}" != "${UNSET_STR}" ]; then
                            tmp="Cannot specify both 'branch' and"
                            tmp="${tmp} '${ext_co_type[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_TYPE} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_co_type[${curr_ext}]="branch"
                            ext_co_loc[${curr_ext}]="${val}"
                        fi
                        ;;
                    externals)
                        if [ "${ext_externals[${curr_ext}]}" != "${UNSET_STR}" ]; then
                            tmp="Duplicate 'externals' keyword, already set to"
                            tmp="${tmp} '${ext_externals[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_KEY} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_externals[${curr_ext}]="${val}"
                        fi
                        ;;
                    from_submodule)
                        errstr=$(cfgerr ${CFG_UNSUPPORTED} ${lineno} ${1} \
                                        "${errstr}" "${tmp}")
                        num_errors=$((num_errors + 1))
                        ;;
                    hash)
                        if [ "${ext_co_type[${curr_ext}]}" != "${UNSET_STR}" ]; then
                            tmp="Cannot specify both 'hash' and "
                            tmp="${tmp} '${ext_co_type[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_TYPE} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_co_type[${curr_ext}]="hash"
                            ext_co_loc[${curr_ext}]="${val}"
                        fi
                        ;;
                    local_path)
                        if [ "${ext_local_path[${curr_ext}]}" != "${UNSET_STR}" ]; then
                            tmp="Duplicate 'local_path' keyword, already set to"
                            tmp="${tmp} '${ext_local_path[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_KEY} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_local_path[${curr_ext}]="${val}"
                        fi
                        ;;
                    repo_url)
                        if [ "${ext_repo_url[${curr_ext}]}" != "${UNSET_STR}" ]; then
                            tmp="Duplicate 'repo_url' keyword, already set to"
                            tmp="${tmp} '${ext_repo_url[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_KEY} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_repo_url[${curr_ext}]="${val}"
                        fi
                        ;;
                    required)
                        if [ "${val,,}" == "true" ]; then
                            ext_required[${curr_ext}]=1
                        else
                            ext_required[${curr_ext}]=0
                        fi
                        ;;
                    sparse)
                        if [ "${ext_sparse_file[${curr_ext}]}" != "${NONE_STR}" ]; then
                            tmp="Duplicate 'sparse' keyword, already set to"
                            tmp="${tmp} '${ext_sparse_file[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_KEY} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_sparse_file[${curr_ext}]="${val}"
                        fi
                        ;;
                    tag)
                        if [ "${ext_co_type[${curr_ext}]}" != "${UNSET_STR}" ]; then
                            tmp="Cannot specify both 'tag' and "
                            tmp="${tmp} '${ext_co_type[${curr_ext}]}'"
                            errstr=$(cfgerr ${CFG_DUPLICATE_TYPE} ${lineno} ${1} \
                                            "${errstr}" "${tmp}")
                            num_errors=$((num_errors + 1))
                        else
                            ext_co_type[${curr_ext}]="tag"
                            ext_co_loc[${curr_ext}]="${val}"
                        fi
                        ;;
                    *)
                        errstr=$(cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} \
                                        "${errstr}" "Unknown key '${key}'")
                        num_errors=$((num_errors + 1))
                        ;;
                    esac
            else
                errstr=$(cfgerr ${CFG_INTERNAL_ERR} ${lineno} ${1} "${errstr}" \
                                "Invalid character in '${val}'")
                num_errors=$((num_errors + 1))
            fi
        else
            tmp="Invalid keyword, '${key}'"
            errstr=$(cfgerr ${CFG_KEYWORD_ERROR} ${lineno} ${1} "${errstr}"   \
                            "${tmp}, in ${curr_ext} section")
            num_errors=$((num_errors + 1))
        fi
    else
        errstr=$(cfgerr ${CFG_SYNTAX_ERROR} ${lineno} ${1}        \
                        "${errstr}" "Syntax error")
        num_errors=$((num_errors + 1))
    fi
done < "${1}"
externals_filename="${1}"
# Check for any missing keywords on the last parsed section
if [ -n "${curr_ext}" -a "${curr_ext}" != "${CFG_DESC_NAME}" ]; then
    ## Check the external we just parsed
    check_missing_keywords "${curr_ext}"
fi


# Finalize error string
if [ ${num_errors} -gt 1 ]; then
    errstr="${num_errors} errors found\n${errstr}"
fi
# End of parsing, cleanup
unset curr_ext
unset ext
unset inline
unset key
unset line
unset num_errors
unset tmp
unset val
unset version

print_externals_cfg() {
    ## Pretty print this externals configuration
    local ext
    local tmp
    for ext in $(externals_list); do
        echo "[${ext}]"
        echo "  $(external_checkout_type ${ext}) = $(external_checkout_loc ${ext})"
        echo "  local_path = $(external_local_path ${ext})"
        echo "  repo_url = $(external_repo_url ${ext})"
        tmp="$(external_sparse ${ext})"
        if [ "${tmp}" != "${NONE_STR}" ]; then
            echo "  sparse = ${tmp}"
        fi
        tmp="$(external_externals ${ext})"
        if [ "${tmp}" != "${NONE_STR}" ]; then
            echo "  externals = ${tmp}"
        fi
        echo "  required = $(external_required ${ext})"
        echo ""
    done
    echo "[${CFG_DESC_NAME}]"
    echo "  ${VERSION_KEY} = ${version}"
}

export externals
export ext_co_type
export ext_co_loc
export ext_local_path
export ext_repo_url
export ext_externals
export ext_required
export ext_sparse_file
