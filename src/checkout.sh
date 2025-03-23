# rm -rf sparseTest; git clone -o NorESM git@github.com:NorESMhub/CAM sparseTest && cd sparseTest && git checkout noresm2_5_017_cam6_4_041 && git config core.sparseCheckoutCone true && git submodule init -- src/physics/clubb && (cd src/physics && rmdir clubb && git clone --depth=1 --no-checkout $(git config submodule.clubb.url) clubb) && git -C src/physics/clubb sparse-checkout set --stdin < src/physics/.clubb_sparse_checkout && git submodule absorbgitdirs -- src/physics/clubb && git sparse-checkout list

# Sparse checkout sequence
# git config core.sparseCheckoutCone true
# git submodule init -- <path_to_submodule>
# rmdir <path_to_submodule>
# cd <path_to_submodule>/..
# git clone --depth=1 --no-checkout $(git config submodule.<submodname>.url) <submodname>
# git -C <path_to_submodule> sparse-checkout set --stdin < <sparse-file>
# git submodule absorbgitdirs -- <path_to_submodule>

script_dir="$(cd $(dirname ${0}); pwd -P)"

# Load utilities
if [ -f "${script_dir}/utils.sh" ]; then
    . "${script_dir}/utils.sh"
else
    echo "ERROR: Cannot find utilities script, '${script_dir}/utils.sh'"
    exit 1
fi

COMPONENTS=()
EXTERNALS_FILE="${EXTERNALS_FILE:-Externals.cfg}" # Default externals.cfg filename
OPTIONAL=${OPTIONAL:-false}     # Flag to turn on optional externals checkout

opt_desc="By default only the required externals are checked out."
opt_desc="${opt_desc} This flag will also checkout the optional externals."
pos_desc="Specific component(s) to checkout."
pos_desc="${pos_desc} By default, all required externals are checked out."

##: BEGIN checkout_externals description
read -rd '' CDESC << 'EOF'
usage: checkout [OPTIONS] [components ...]

checkout manages checking out groups of externals from git based on an
externals description file. By default only the required externals are
checked out.

If the source tree already has externals checked out, checkout will
attempt to update the externals to match the externals file
EOF
##: END checkout_externals description

## Each 'item' below is 4 consecutive entries
  # 1: Option names (* for positional) separated by a vertical bar
  # 2: Option input hint string (empty string for flags)
  # 3: Option description
  # 4: Option action (not used in help)
##: BEGIN checkout_externals options
export HELP_OPTIONS=(
    # Positional args
    "${POSITIONAL_KEY}" "[<component name> [<component_name [...]]]"
    "${pos_desc}"
    "COMPONENTS+=(\${1})"
    # HELP
    "--help" "" "Show this help message and exit."
    "help \"\${CDESC}\"; exit 0"
    # Specify externals file
    "--externals" "<EXTERNALS FILENAME>"
    "Externals description filename. Default: ${EXTERNALS_FILE}"
    "EXTERNALS_FILE=\"\${2}\"; shift"
    # Checkout optional components
    "--optional" "" "${opt_desc}"
    "OPTIONAL=true"
)
##: END checkout_externals options
unset opt_desc
unset pos_desc

checkout_externals() {
    # $1 is the name of the externals file
    if [ -f "${script_dir}/externals_file.sh" ]; then
        . "${script_dir}/externals_file.sh" ${1}
    else
        echo "ERROR: Cannot find externals file script"
        exit 1
    fi
    if found_errors; then
        report_errors
    else
        print_externals_cfg
    fi
}

## Process inputs
# Create action array. key is option, value is action string
declare -A actions
for item_ind in $(seq 1 $((${#HELP_OPTIONS[@]} / 4))); do
    ind=$(( (item_ind - 1) * 4 ))
    actions["${HELP_OPTIONS[${ind}]}"]="${HELP_OPTIONS[${ind}+3]}"
done

while [ $# -gt 0 ]; do
    key="${1}"
    if [ "${key:0:2}" == "--" ]; then
        eval ${actions["${key}"]}
    elif [ "${key}" == "-h" ]; then
        help "${CDESC}"
        exit 0
    elif [ "${key:0:1}" == "-" ]; then
        echo "ERROR: Unknown argument, '${key}'"
        help "${CDESC}"
        exit 1
    else
        eval ${actions["${POSITIONAL_KEY}"]}
    fi
    shift
done


checkout_externals Externals.cfg
