set(CMAKE_SYSTEM_NAME Generic)
set(CMAKE_SYSTEM_PROCESSOR ARM)

# ---------------------------------------------------------------
# Toolchain executables
# These are resolved from PATH; set GCC_ARM_PATH env variable
# to point to a non-default toolchain installation.
# ---------------------------------------------------------------
if(DEFINED ENV{GCC_ARM_PATH})
    set(TOOLCHAIN_PREFIX "$ENV{GCC_ARM_PATH}/arm-none-eabi-")
else()
    set(TOOLCHAIN_PREFIX "arm-none-eabi-")
endif()

set(CMAKE_C_COMPILER   ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_CXX_COMPILER ${TOOLCHAIN_PREFIX}g++)
set(CMAKE_ASM_COMPILER ${TOOLCHAIN_PREFIX}gcc)
set(CMAKE_OBJCOPY      ${TOOLCHAIN_PREFIX}objcopy)
set(CMAKE_OBJDUMP      ${TOOLCHAIN_PREFIX}objdump)
set(CMAKE_SIZE         ${TOOLCHAIN_PREFIX}size)

set(CMAKE_C_COMPILER_FORCED   TRUE)
set(CMAKE_CXX_COMPILER_FORCED TRUE)
set(CMAKE_C_COMPILER_ID       GNU)
set(CMAKE_CXX_COMPILER_ID     GNU)

# ---------------------------------------------------------------
# Compile flags common to C and ASM
# STM32_MCU_FLAGS must be set by the project CMakeLists.txt
# before including this file.
# ---------------------------------------------------------------
set(COMMON_FLAGS
    "${STM32_MCU_FLAGS} -Os -g3 -Wall -fstack-usage \
-fdata-sections -ffunction-sections")

set(CMAKE_C_FLAGS_INIT   "${COMMON_FLAGS}")
set(CMAKE_ASM_FLAGS_INIT "${COMMON_FLAGS}")

# ---------------------------------------------------------------
# Linker flags
# STM32_LINKER_SCRIPT  — path relative to CMAKE_SOURCE_DIR
# STM32_LINKER_OPTION  — extra flags (e.g. -u _printf_float)
# ---------------------------------------------------------------
set(CMAKE_EXE_LINKER_FLAGS_INIT
    "${STM32_MCU_FLAGS} \
-specs=nano.specs \
-T \"${CMAKE_SOURCE_DIR}/${STM32_LINKER_SCRIPT}\" \
-Wl,-Map=${CMAKE_PROJECT_NAME}.map,--cref \
-Wl,--gc-sections \
-Wl,--print-memory-usage \
${STM32_LINKER_OPTION}")

# Prevent CMake from trying to link test executables with these flags
# (required when cross-compiling)
set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY)
