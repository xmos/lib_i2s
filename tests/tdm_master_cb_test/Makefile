ifeq ($(USING_XWAF),1)
all:
	xwaf configure build --config $(CONFIG)
else # USING_XWAF
# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = SLICEKIT-L16

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME = tdm_master_cb_test

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_i2s

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.
COMMON_FLAGS = -O3 -g

$(foreach out,0 1 2 3 4,\
 $(foreach in,0 1 2 3 4,\
   $(eval \
    XCC_FLAGS_smoke_$(out)$(in) = $(COMMON_FLAGS) -DNUM_OUT=$(out) -DNUM_IN=$(in) -DSMOKE\
    ) \
   $(eval \
    XCC_FLAGS_nightly_$(out)$(in) = $(COMMON_FLAGS) -DNUM_OUT=$(out) -DNUM_IN=$(in)\
    ) \
 ) \
)

# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

# The VERBOSE variable, if set to 1, enables verbose output from the make system.
VERBOSE = 0

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
endif # USING_XWAF
