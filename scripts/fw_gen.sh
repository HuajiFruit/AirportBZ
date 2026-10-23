#!/bin/sh

#  fw_gen.sh
#  itlwm
#
#  Created by qcwap on 2020/3/10.
#  Copyright © 2020 Zhong Xianyao. All rights reserved.
set -eu

/bin/sh "${PROJECT_DIR}/scripts/prepare-mackernelsdk.sh" "${PROJECT_DIR}/MacKernelSDK"

target_file="${PROJECT_DIR}/include/FwBinary.cpp"
if [ -f "$target_file" ]; then
exit 0
fi
while [ $# -gt 0 ];
do
    case $1 in
    -P) fw_files=$2
    shift
    ;;
    
    esac
    shift
done

script_file="${PROJECT_DIR}/scripts/zlib_compress_fw.py"
python3 "${script_file}" "${target_file}" "${fw_files}"
