set(LIB_NAME lib_i2s)
set(LIB_VERSION 5.0.0)
set(LIB_INCLUDES api src)
set(LIB_COMPILER_FLAGS -O3)
set(LIB_DEPENDENT_MODULES "lib_xassert"
                          "lib_logging")

XMOS_REGISTER_MODULE()
