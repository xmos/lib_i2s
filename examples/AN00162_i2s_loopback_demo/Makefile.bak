# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = XR-AUDIO-216-MC

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = 

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_gpio lib_i2c lib_i2s

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
XCC_FLAGS = $(EXTRA_FLAGS) -O2 -report -g -DSIM=1 -DUSE_HW_DIVIDER=1

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 0


test: bin/i2s_loopback_demo.xe
	xsim bin/i2s_loopback_demo.xe --plugin LoopbackPort.dll '-port tile[0] XS1_PORT_1D 1 0 -port tile[1] XS1_PORT_1E 1 0'

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
