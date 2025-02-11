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

if [ -f "${script_dir}/externals_file.sh" ]; then
    . "${script_dir}/externals_file.sh"
else
    echo "ERROR: Cannot find externals file script"
    exit 1
fi

declare externals=()
declare -A component_cfg

errmsg=$(parse_externals_cfg_file "${1}" ${externals})
res=$?

if [ ${res} -gt 0 ]; then
    echo -e "${errmsg}"
    exit ${res}
else
    # Read externals from errmsg into an array
    IFS=' ' read -r -a externals <<< "${errmsg}"
    echo "Externals.cfg successfully parsed"
fi

echo "Externals found: ${externals[@]}"

ext=cam
echo "${ext} keywords: $(external_keywords ${ext})"
