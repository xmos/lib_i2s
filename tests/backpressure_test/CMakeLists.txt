cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

# Get JSON lists
file(READ ${CMAKE_CURRENT_LIST_DIR}/test_params.json JSON_CONTENT)

# Parse the JSON file into variables
string(JSON BITDEPTHS_LIST GET ${JSON_CONTENT} BITDEPTHS)
string(JSON SAMPLE_RATES_LIST GET ${JSON_CONTENT} SAMPLE_RATES)
string(JSON I2S_LINES_LIST GET ${JSON_CONTENT} I2S_LINES)
string(JSON RX_TX_INCS_LIST GET ${JSON_CONTENT} RX_TX_INCS)

# Convert JSON lists to CMake lists
string(JSON NUM_BITDEPTHS LENGTH ${BITDEPTHS_LIST})
string(JSON NUM_SAMPLE_RATES LENGTH ${SAMPLE_RATES_LIST})
string(JSON NUM_I2S_LINES LENGTH ${I2S_LINES_LIST})
string(JSON NUM_RX_TX_INCS LENGTH ${RX_TX_INCS_LIST})

# Subtract one off each of the lengths because RANGE includes last element
math(EXPR NUM_BITDEPTHS "${NUM_BITDEPTHS} - 1")
math(EXPR NUM_SAMPLE_RATES "${NUM_SAMPLE_RATES} - 1")
math(EXPR NUM_I2S_LINES "${NUM_I2S_LINES} - 1")
math(EXPR NUM_RX_TX_INCS "${NUM_RX_TX_INCS} - 1")

project(test_i2s_backpressure)
set(APP_HW_TARGET           XCORE-200-EXPLORER)
set(APP_PCA_ENABLE          ON)
set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

# Iterate through combinations
foreach(i RANGE 0 ${NUM_BITDEPTHS})
    string(JSON BITDEPTH GET ${BITDEPTHS_LIST} ${i})
    foreach(j RANGE 0 ${NUM_SAMPLE_RATES})
        string(JSON SAMPLE_RATE GET ${SAMPLE_RATES_LIST} ${j})
        foreach(k RANGE 0 ${NUM_I2S_LINES})
            string(JSON I2S_LINES GET ${I2S_LINES_LIST} ${k})
            foreach(l RANGE 0 ${NUM_RX_TX_INCS})
                string(JSON RX_TX GET ${RX_TX_INCS_LIST} ${l})
                string(JSON RX GET ${RX_TX} RX) # Extract out the pair of values
                string(JSON TX GET ${RX_TX} TX)

                set(cfg_name "${BITDEPTH}_${SAMPLE_RATE}_${I2S_LINES}_${RX}_${TX}")
                message(STATUS "Building cfg_name: ${cfg_name}")

                set(APP_COMPILER_FLAGS_${cfg_name}   
                                            -O3
                                            -report
                                            -g
                                            -DSAMPLE_FREQUENCY=${SAMPLE_RATE}
                                            -DDATA_BITS=${BITDEPTH}
                                            -DNUM_I2S_LINES=${I2S_LINES}
                                            -DRECEIVE_DELAY_INCREMENT=${RX}
                                            -DSEND_DELAY_INCREMENT=${TX}
                                            -DGENERATE_MCLK=1
                                            -DSIM=1
                                            -DDEBUG_PRINT_ENABLE=1)

            endforeach()
        endforeach()
    endforeach()
endforeach()

XMOS_REGISTER_APP()
