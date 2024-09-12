cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../test_deps.cmake)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON SMOKE_LIST GET ${JSON_CONTENT} SMOKE)
string(JSON NUM_INVERTS_LIST GET ${JSON_CONTENT} INVERT)
string(JSON I2S_LINES_LIST GET ${JSON_CONTENT} I2S_LINES)

# Convert JSON lists to CMake lists
string(JSON NUM_SMOKES LENGTH ${SMOKE_LIST})
string(JSON NUM_INVERTS LENGTH ${NUM_INVERTS_LIST})
string(JSON NUM_I2S_LINES LENGTH ${I2S_LINES_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_SMOKES "${NUM_SMOKES} - 1")
math(EXPR NUM_INVERTS "${NUM_INVERTS} - 1")
math(EXPR NUM_I2S_LINES "${NUM_I2S_LINES} - 1")

set(APP_HW_TARGET           XCORE-200-EXPLORER)
project(test_i2s_frame_slave_4b)
set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)
set(APP_PCA_ENABLE          ON)

# Iterate through combinations
foreach(j RANGE 0 ${NUM_SMOKES})
    string(JSON SMOKE GET ${SMOKE_LIST} ${j})
    foreach(k RANGE 0 ${NUM_INVERTS})
        string(JSON INVERT GET ${NUM_INVERTS_LIST} ${k})
        foreach(l RANGE 0 ${NUM_I2S_LINES})
            string(JSON INPUT_OUTPUT GET ${I2S_LINES_LIST} ${l})
            string(JSON INPUT GET ${INPUT_OUTPUT} INPUT) # Extract out the pair of values for input and output
            string(JSON OUTPUT GET ${INPUT_OUTPUT} OUTPUT)
            set(config "${INVERT}_${INPUT}_${OUTPUT}_${SMOKE}")
            message(STATUS "Building config: ${config}")

            set(APP_COMPILER_FLAGS_${config}
                                        -O3
                                        -report
                                        -g
                                        -DNUM_OUT=${OUTPUT}
                                        -DNUM_IN=${INPUT})
            if(${INVERT} MATCHES 1)
                list(APPEND APP_COMPILER_FLAGS_${config} -DSLAVE_INVERT_BCLK=1)
            endif()
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()
