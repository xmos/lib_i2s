cmake_minimum_required(VERSION 3.21)
include($ENV{XMOS_CMAKE_PATH}/xcommon.cmake)
project(app_i2s_frame_slave_loopback_demo)

set(APP_HW_TARGET           xk-audio-316-mc.xn)

include(${CMAKE_CURRENT_LIST_DIR}/../../deps.cmake)

set(APP_COMPILER_FLAGS      -O2
                            -report
                            -g
                            -DBOARD_SUPPORT_BOARD=XK_AUDIO_316_MC_AB
                            -DDEBUG_PRINT_ENABLE=1)

set(APP_PCA_ENABLE          ON)

set(XMOS_SANDBOX_DIR        ${CMAKE_CURRENT_LIST_DIR}/../../..)

XMOS_REGISTER_APP()
