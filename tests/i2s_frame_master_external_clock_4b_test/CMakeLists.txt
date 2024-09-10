cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON I2S_LINES_LIST GET ${JSON_CONTENT} I2S_LINES)

# Convert JSON lists to CMake lists
string(JSON NUM_I2S_LINES LENGTH ${I2S_LINES_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_I2S_LINES "${NUM_I2S_LINES} - 1")

set(APP_PCA_ENABLE          ON)
project(test_i2s_frame_master_external_clock_4b)
set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)
set(APP_HW_TARGET           XCORE-200-EXPLORER)

# Iterate through combinations

foreach(l RANGE 0 ${NUM_I2S_LINES})
    string(JSON INPUT_OUTPUT GET ${I2S_LINES_LIST} ${l})
    string(JSON INPUT GET ${INPUT_OUTPUT} INPUT) # Extract out the pair of values for input and output
    string(JSON OUTPUT GET ${INPUT_OUTPUT} OUTPUT)
    set(config "${INPUT}_${OUTPUT}")
    message(STATUS "Building config: ${config}")

    set(APP_COMPILER_FLAGS_${config}
                                -O3
                                -report
                                -g
                                -DNUM_OUT=${OUTPUT}
                                -DNUM_IN=${INPUT})
endforeach()

XMOS_REGISTER_APP()
