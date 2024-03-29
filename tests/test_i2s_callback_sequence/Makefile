ifeq ($(USING_XWAF),1)
all:
	xwaf configure build --config $(CONFIG)
else # USING_XWAF
# The TARGET variable determines what target system the application is
# compiled for. It either refers to an XN file in the source directories
# or a valid argument for the --target option when compiling

TARGET ?= XCORE-200-EXPLORER

ifeq ($(XCORE_AI), 1)
TARGET = XCORE-AI-EXPLORER
endif
ifeq ($(CONFIG), XCORE_AI)
TARGET = XCORE-AI-EXPLORER
endif

# The APP_NAME variable determines the name of the final .xe file. It should
# not include the .xe postfix. If left blank the name will default to
# the project name
APP_NAME =

# The USED_MODULES variable lists other module used by the application.
USED_MODULES = lib_i2s

# The flags passed to xcc when building the application
# You can also set the following to override flags for a particular language:
# XCC_XC_FLAGS, XCC_C_FLAGS, XCC_ASM_FLAGS, XCC_CPP_FLAGS
# If the variable XCC_MAP_FLAGS is set it overrides the flags passed to
# xcc for the final link (mapping) stage.

NUMS_IN_OUT ?= 4;4 4;0 0;4
TDM_CHANS_PER_FRAME ?= 8
SMOKE ?= 1
TDM ?= 0
MASTER ?= 1

COMMON_FLAGS = -O2 -g

ifeq ($(TDM), 1)
  ifeq ($(SMOKE), 1)
    $(foreach in_out,$(NUMS_IN_OUT),\
      $(eval \
        XCC_FLAGS_tdm_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out)))_$(TDM_CHANS_PER_FRAME)_smoke = $(COMMON_FLAGS) -DTDM -DTDM_CHANS_PER_FRAME=$(TDM_CHANS_PER_FRAME) -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out))) -DSMOKE\
      ) \
    )
  else
    $(foreach in_out,$(NUMS_IN_OUT),\
      $(eval \
        XCC_FLAGS_tdm_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out)))_$(TDM_CHANS_PER_FRAME) = $(COMMON_FLAGS) -DTDM -DTDM_CHANS_PER_FRAME=$(TDM_CHANS_PER_FRAME) -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out)))\
      ) \
    )
  endif
else
  ifeq ($(MASTER), 1)
    ifeq ($(SMOKE), 1)
      $(foreach in_out,$(NUMS_IN_OUT),\
        $(eval \
          XCC_FLAGS_master_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out)))_smoke = $(COMMON_FLAGS) -DMASTER -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out))) -DSMOKE\
        ) \
      )
    else
      $(foreach in_out,$(NUMS_IN_OUT),\
        $(eval \
          XCC_FLAGS_master_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out))) = $(COMMON_FLAGS) -DMASTER -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out)))\
        ) \
      )
    endif
  else
    ifeq ($(SMOKE), 1)
      $(foreach in_out,$(NUMS_IN_OUT),\
        $(eval \
          XCC_FLAGS_slave_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out)))_smoke = $(COMMON_FLAGS) -DSLAVE -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out))) -DSMOKE\
        ) \
      )
    else
      $(foreach in_out,$(NUMS_IN_OUT),\
        $(eval \
          XCC_FLAGS_slave_$(word 1, $(subst ;, ,$(in_out)))_$(word 2, $(subst ;, ,$(in_out))) = $(COMMON_FLAGS) -DSLAVE -DNUM_OUT=$(word 2, $(subst ;, ,$(in_out))) -DNUM_IN=$(word 1, $(subst ;, ,$(in_out)))\
        ) \
      )
    endif
  endif
endif

XMOS_MAKE_PATH ?= ../..
-include $(XMOS_MAKE_PATH)/xcommon/module_xcommon/build/Makefile.common
endif # USING_XWAF
