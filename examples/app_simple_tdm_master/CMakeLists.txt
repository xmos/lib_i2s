cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_simple_tdm_master)

set(APP_HW_TARGET           XCORE-AI-EXPLORER)

include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

set(APP_COMPILER_FLAGS      -Os
                            -g
                            -report
                            )

set(APP_PCA_ENABLE          ON)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

XMOS_REGISTER_APP()
