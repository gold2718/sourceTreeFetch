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
EXTERNAL_KEYWORDS=("branch" "externals" "from_submodule" "hash" "local_path"  \
                            "protocol" "repo_url" "required" "sparse" "tag")

SECTION_REGEX='\[[[:space:]]*([A-Za-z0-9-_]+)[[:space:]]*]'
SECTION_REGEX='\[[[:space:]]*([-A-Za-z0-9_]+)[[:space:]]*]'

parse_externals_cfg_file() {
    ## Given a file, parse an externals file into an internal format
    local inline
    local key
    local line
    local value
    while read line; do
        inline="$(echo ${line} | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
        inline="$(strip_arg ${line})"
        if [ ${#inline} -eq 0 ]; then
            # Blank line, ignore
            continue
        elif [ "${inline:0:1}" == "#" ]; then
            # Comment, ignore
            continue
        elif [[ "${inline}" =~ ${SECTION_REGEX} ]]; then
            echo "${BASH_REMATCH[1]}"
        elif [ -n "$(echo ${inline} | grep '=')" ]; then
            key="$(parse_keyword ${inline})"
            val="$(parse_value ${inline})"
#            echo "${key} : ${val}"
        else
            echo "What's this? '${inline}'"
        fi
    done < "${1}"
}
