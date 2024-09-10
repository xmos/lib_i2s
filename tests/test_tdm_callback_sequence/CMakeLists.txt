cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON SMOKE_LIST GET ${JSON_CONTENT} SMOKE)
string(JSON NUMS_IN_OUT_LIST GET ${JSON_CONTENT} NUMS_IN_OUT)

# Convert JSON lists to CMake lists
string(JSON NUM_SMOKES LENGTH ${SMOKE_LIST})
string(JSON NUM_NUMS_IN_OUT LENGTH ${NUMS_IN_OUT_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_SMOKES "${NUM_SMOKES} - 1")
math(EXPR NUM_NUMS_IN_OUT "${NUM_NUMS_IN_OUT} - 1")

set(APP_PCA_ENABLE          ON)
project(test_tdm_callback_sequence)
set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)
set(APP_HW_TARGET           XCORE-200-EXPLORER)

# Iterate through combinations
foreach(j RANGE 0 ${NUM_SMOKES})
    string(JSON SMOKE GET ${SMOKE_LIST} ${j})
    foreach(l RANGE 0 ${NUM_NUMS_IN_OUT})
        string(JSON INPUT_OUTPUT GET ${NUMS_IN_OUT_LIST} ${l})
        string(JSON INPUT GET ${INPUT_OUTPUT} INPUT) # Extract out the pair of values for input and output
        string(JSON OUTPUT GET ${INPUT_OUTPUT} OUTPUT)
        string(JSON TDM_CHANS_PER_FRAME GET ${INPUT_OUTPUT} TDM_CHANS_PER_FRAME)
        set(config "${INPUT}_${OUTPUT}_${TDM_CHANS_PER_FRAME}_${SMOKE}")
        message(STATUS "Building config: ${config}")

        set(APP_COMPILER_FLAGS_${config}
                                    -O3
                                    -report
                                    -g
                                    -DNUM_OUT=${OUTPUT}
                                    -DNUM_IN=${INPUT}
                                    -DTDM_CHANS_PER_FRAME=${TDM_CHANS_PER_FRAME}
                                    -DTDM=1)

        if(${SMOKE} MATCHES 1)
            list(APPEND APP_COMPILER_FLAGS_${config} -DSMOKE=1)
        endif()
    endforeach()
endforeach()

XMOS_REGISTER_APP()
