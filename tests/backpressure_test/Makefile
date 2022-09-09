ifeq ($(USING_XWAF),1)
all:
	xwaf configure build --config $(CONFIG)
else # USING_XWAF
# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling

ifeq ($(CONFIG),XCORE_AI)
TARGET = XCORE-AI-EXPLORER
else
TARGET = XCORE-200-EXPLORER
endif

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME =

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_logging lib_i2s

SHARED_FLAGS = -O2 -report -g -DSIM=1 -DDEBUG_PRINT_ENABLE=1 -DGENERATE_MCLK

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.

SAMPLE_RATES ?= 768000 384000 192000
CHANS ?= 1 4
RX_TX_INCS ?= 5;5 10;0 0;10
BITDEPTHS ?= 8 16 32

XCC_FLAGS_XCORE_AI = $(SHARED_FLAGS) -DSAMPLE_FREQUENCY=768000 -DNUM_I2S_LINES=4 -DRECEIVE_DELAY_INCREMENT=5 -DSEND_DELAY_INCREMENT=5

$(foreach db,$(BITDEPTHS), \
  $(foreach sr,$(SAMPLE_RATES),\
    $(foreach chan,$(CHANS),\
      $(foreach incs,$(RX_TX_INCS),\
        $(eval \
          XCC_FLAGS_$(db)_$(sr)_$(chan)_$(word 1, $(subst ;, ,$(incs)))_$(word 2, $(subst ;, ,$(incs))) = $(SHARED_FLAGS) -DDATA_BITS=$(db) -DSAMPLE_FREQUENCY=$(sr) -DNUM_I2S_LINES=$(chan) -DRECEIVE_DELAY_INCREMENT=$(word 1, $(subst ;, ,$(incs))) -DSEND_DELAY_INCREMENT=$(word 2, $(subst ;, ,$(incs)))\
        ) \
      ) \
    ) \
  )\
)

test: bin/i2s_loopback_demo.xe
	xsim bin/i2s_loopback_demo.xe --plugin LoopbackPort.dll '-port tile[0] XS1_PORT_1G 1 0 -port tile[0] XS1_PORT_1A 1 0'

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
endif # USING_XWAF
