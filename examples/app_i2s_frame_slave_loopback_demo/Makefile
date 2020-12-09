# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = XR-AUDIO-216-MC

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME =

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_gpio(>=1.1.0) lib_i2c(>=5.0.0) lib_i2s(>=3.0.0)

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
XCC_FLAGS = $(EXTRA_FLAGS) -O3 -report -g -DSIM_LOOPBACK_TEST=0 -DDEBUG_PRINT_ENABLE=1

# sim:
# 	xsim bin/i2s_frame_slave_loopback_demo.xe --max-cycles 200000 --plugin LoopbackPort.dll '-port tile[0] XS1_PORT_1M 1 0 -port tile[0] XS1_PORT_1I 1 0 -port tile[0] XS1_PORT_1N 1 0 -port tile[0] XS1_PORT_1J 1 0 -port tile[0] XS1_PORT_1O 1 0 -port tile[0] XS1_PORT_1K 1 0 -port tile[0] XS1_PORT_1P 1 0 -port tile[0] XS1_PORT_1L 1 0 -port tile[0] XS1_PORT_1A 1 0 -port tile[0] XS1_PORT_1F 1 0 -port tile[0] XS1_PORT_1B 1 0 -port tile[0] XS1_PORT_1H 1 0 -port tile[0] XS1_PORT_1C 1 0 -port tile[0] XS1_PORT_1G 1 0 ' --trace-plugin VcdPlugin.dll '-tile tile[0] -o trace.vcd -xe bin/i2s_frame_slave_loopback_demo.xe -ports -ports-detailed -cores -instructions'

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
