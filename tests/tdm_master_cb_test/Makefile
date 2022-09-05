ifeq ($(USING_XWAF),1)
all:
	xwaf configure build --config $(CONFIG)
else # USING_XWAF
# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling
TARGET = XCORE-200-EXPLORER

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

NUMS_IN_OUT ?= 4;4 2;2 4;0 0;4
SMOKE ?= 1

ifeq ($(SMOKE), 1)
  $(foreach in_out,$(NUMS_IN_OUT),\
    $(eval \
      XCC_FLAGS_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out)))_smoke = $(COMMON_FLAGS) -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out))) -DSMOKE\
    ) \
  )
else
  $(foreach in_out,$(NUMS_IN_OUT),\
    $(eval \
      XCC_FLAGS_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out))) = $(COMMON_FLAGS) -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out)))\
    ) \
  )
endif

# The XCORE_ARM_PROJECT variable, if set to 1, configures this
# project to create both xCORE and ARM binaries.
XCORE_ARM_PROJECT = 0

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
endif # USING_XWAF
