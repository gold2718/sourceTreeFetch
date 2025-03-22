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

export INDENT=24             # Description indent for help lines
export LINELEN=80            # Output line length
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

##: BEGIN checkout_externals options
export HELP_OPTIONS=(
    "*" "[<component name> [<component_name [...]]]" "${pos_desc}"
    "--help" "" "Show this help message and exit."
    "--externals" "<EXTERNALS FILENAME>"
    "Externals description filename. Default: ${EXTERNALS_FILE}"
    "--optional" "" "${opt_desc}"
)
##: END checkout_externals options
unset opt_desc
unset pos_desc

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

# XXgoldyXX: v debug only
help "${CDESC}"
exit 0
# XXgoldyXX: ^ debug only

checkout_externals Externals.cfg
