cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON BITDEPTHS_LIST GET ${JSON_CONTENT} BITDEPTHS)
string(JSON SMOKE_LIST GET ${JSON_CONTENT} SMOKE)
string(JSON MCLK_FAMILIES_LIST GET ${JSON_CONTENT} MCLK_FAMILIES)
string(JSON I2S_LINES_LIST GET ${JSON_CONTENT} I2S_LINES)

# Convert JSON lists to CMake lists
string(JSON NUM_BITDEPTHS LENGTH ${BITDEPTHS_LIST})
string(JSON NUM_SMOKES LENGTH ${SMOKE_LIST})
string(JSON NUM_MCLK_FAMILIES LENGTH ${MCLK_FAMILIES_LIST})
string(JSON NUM_I2S_LINES LENGTH ${I2S_LINES_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_BITDEPTHS "${NUM_BITDEPTHS} - 1")
math(EXPR NUM_SMOKES "${NUM_SMOKES} - 1")
math(EXPR NUM_MCLK_FAMILIES "${NUM_MCLK_FAMILIES} - 1")
math(EXPR NUM_I2S_LINES "${NUM_I2S_LINES} - 1")

set(APP_PCA_ENABLE          ON)
project(test_i2s_frame_master)
set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)
set(APP_HW_TARGET           XCORE-200-EXPLORER)

# Iterate through combinations
foreach(i RANGE 0 ${NUM_BITDEPTHS})
    string(JSON BITDEPTH GET ${BITDEPTHS_LIST} ${i})
    foreach(j RANGE 0 ${NUM_SMOKES})
        string(JSON SMOKE GET ${SMOKE_LIST} ${j})
        foreach(k RANGE 0 ${NUM_MCLK_FAMILIES})
            string(JSON MCLK_FAMILY GET ${MCLK_FAMILIES_LIST} ${k})
            foreach(l RANGE 0 ${NUM_I2S_LINES})
                string(JSON INPUT_OUTPUT GET ${I2S_LINES_LIST} ${l})
                string(JSON INPUT GET ${INPUT_OUTPUT} INPUT) # Extract out the pair of values for input and output
                string(JSON OUTPUT GET ${INPUT_OUTPUT} OUTPUT)
                set(config "${BITDEPTH}_${MCLK_FAMILY}_${INPUT}_${OUTPUT}_${SMOKE}")
                message(STATUS "Building config: ${config}")

                set(APP_COMPILER_FLAGS_${config}
                                            -O3
                                            -report
                                            -g
                                            -DMCLK_FAMILY=${MCLK_FAMILY}
                                            -DDATA_BITS=${BITDEPTH}
                                            -DNUM_OUT=${OUTPUT}
                                            -DNUM_IN=${INPUT})

                if(${SMOKE} MATCHES 1)
                    list(APPEND APP_COMPILER_FLAGS_${config} -DSMOKE=1)
                endif()
            endforeach()
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()
