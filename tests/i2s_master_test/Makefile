# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling.

TARGET = SLICEKIT-L16

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name

APP_NAME = 

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
#
#    XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
#
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.

COMMON_FLAGS = -O2 -g -save-temps -DDEBUG_PRINT_ENABLE=1 -report

XCC_FLAGS_clk_48_1 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=24576000 -DSAMPLE_FREQUENCY=48000 -DNUM_CHANS=1
XCC_FLAGS_clk_441_1 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=22579200 -DSAMPLE_FREQUENCY=44100 -DNUM_CHANS=1

XCC_FLAGS_clk_48_2 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=24576000 -DSAMPLE_FREQUENCY=48000 -DNUM_CHANS=2
XCC_FLAGS_clk_441_2 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=22579200 -DSAMPLE_FREQUENCY=44100 -DNUM_CHANS=2

XCC_FLAGS_clk_48_3 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=24576000 -DSAMPLE_FREQUENCY=48000 -DNUM_CHANS=3
XCC_FLAGS_clk_441_3 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=22579200 -DSAMPLE_FREQUENCY=44100 -DNUM_CHANS=3

XCC_FLAGS_clk_48_4 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=24576000 -DSAMPLE_FREQUENCY=48000 -DNUM_CHANS=4
XCC_FLAGS_clk_441_4 = $(COMMON_FLAGS) -DMASTER_CLOCK_FREQUENCY=22579200 -DSAMPLE_FREQUENCY=44100 -DNUM_CHANS=4

# The USED_MODULES variable lists other module used by the application.

USED_MODULES = lib_i2s lib_logging

#=============================================================================
# The following part of the Makefile includes the common build infrastructure
# for compiling XMOS applications. You should not need to edit below here.

XMOS_MAKE_PATH ?= ../..
include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
