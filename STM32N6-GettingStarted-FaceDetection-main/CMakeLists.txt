cmake_minimum_required(VERSION 3.22)

# ---------------------------------------------------------------
# Board selection — set via -DBOARD=<name> or CMakePresets.json
#   Supported values:
#     STM32N6570-DK       (Discovery Kit)
#     NUCLEO-N657X0-Q     (Nucleo board)
# ---------------------------------------------------------------
if(NOT DEFINED BOARD)
    set(BOARD "STM32N6570-DK" CACHE STRING
        "Target board: STM32N6570-DK or NUCLEO-N657X0-Q")
endif()

if(NOT BOARD STREQUAL "STM32N6570-DK" AND
   NOT BOARD STREQUAL "NUCLEO-N657X0-Q")
    message(FATAL_ERROR
        "Unknown BOARD '${BOARD}'. Use STM32N6570-DK or NUCLEO-N657X0-Q")
endif()

message(STATUS "Board   : ${BOARD}")

# MCU flags — shared by both boards (Cortex-M55, hard-float, CMSE)
set(STM32_MCU_FLAGS
    "-mcpu=cortex-m55 -mfpu=fpv5-d16 -mfloat-abi=hard -mcmse")

# Linker script (both boards have the same name, different directory)
set(STM32_LINKER_SCRIPT
    "Application/${BOARD}/STM32CubeIDE/STM32N657xx.ld")

# Extra linker options appended after the toolchain defaults
set(STM32_LINKER_OPTION
    "-u _printf_float -Wl,--no-warn-rwx-segments")

# Pull in the ARM GNU toolchain configuration
include("${CMAKE_SOURCE_DIR}/gcc-arm-none-eabi.cmake")

# C standard
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release")
endif()
message(STATUS "Build   : ${CMAKE_BUILD_TYPE}")
set(CMAKE_EXPORT_COMPILE_COMMANDS TRUE)

# ---------------------------------------------------------------
# Project
# ---------------------------------------------------------------
set(CMAKE_PROJECT_NAME "FaceDetection_${BOARD}")
project(${CMAKE_PROJECT_NAME})
enable_language(C ASM)

add_executable(${CMAKE_PROJECT_NAME})

# Force .elf extension on all platforms
set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES SUFFIX ".elf")

# ---------------------------------------------------------------
# Common compile definitions
# ---------------------------------------------------------------
target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
    STM32N657xx
    USE_FULL_ASSERT
    USE_FULL_LL_DRIVER
    VECT_TAB_SRAM
    LL_ATON_DUMP_DEBUG_API
    "LL_ATON_PLATFORM=LL_ATON_PLAT_STM32N6"
    "LL_ATON_OSAL=LL_ATON_OSAL_BARE_METAL"
    "LL_ATON_RT_MODE=LL_ATON_RT_ASYNC"
    LL_ATON_SW_FALLBACK
    "LL_ATON_DBG_BUFFER_INFO_EXCLUDED=1"
)

# ---------------------------------------------------------------
# Common include directories
# ---------------------------------------------------------------
target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
    # Board-specific application headers
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Inc

    # AI model (network_ecblobs.h lives alongside generated sources)
    ${CMAKE_SOURCE_DIR}/Model/${BOARD}

    # AI postprocessing wrapper
    ${CMAKE_SOURCE_DIR}/Middlewares/ai-postprocessing-wrapper

    # STM32 vision-models postprocessing
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-vision-models-postprocessing/lib_vision_models_pp/Inc

    # STEdge AI — library headers and NPU runtime
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Inc
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/Devices/STM32N6xx

    # Camera middleware (sensor drivers + ISP)
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/imx335
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/vd55g1
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/vd6g
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/vd1943
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/ov5640
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/ISP_Library/isp/Inc

    # HAL driver headers
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Inc
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Inc/Legacy

    # CMSIS
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/CMSIS/Device/ST/STM32N6xx/Include
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/CMSIS/Include
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/CMSIS/DSP/Include

    # BSP common / shared component headers
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/Common
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/aps256xx

    # LCD utility
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Utilities/lcd
)

# ---------------------------------------------------------------
# Common source files
# ---------------------------------------------------------------

# Postprocessing wrapper (all .c in directory)
file(GLOB POSTPROCESS_SRCS
    ${CMAKE_SOURCE_DIR}/Middlewares/ai-postprocessing-wrapper/*.c)

# Vision-models postprocessing library
file(GLOB VMP_SRCS
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-vision-models-postprocessing/lib_vision_models_pp/Src/*.c)

# ISP library — exclude the template stub (its callbacks are defined in cmw_camera.c)
file(GLOB ISP_SRCS
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/ISP_Library/isp/Src/*.c)
list(FILTER ISP_SRCS EXCLUDE REGEX "isp_conf_template\\.c$")

target_sources(${CMAKE_PROJECT_NAME} PRIVATE
    # ---- Application (board-specific Src dir) ----
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/main.c
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/syscalls.c
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/app_fuseprogramming.c
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/app_camerapipeline.c
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/crop_img.c
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/stm32_lcd_ex.c
    ${CMAKE_SOURCE_DIR}/Application/${BOARD}/Src/stm32n6xx_it.c

    # ---- AI postprocessing ----
    ${POSTPROCESS_SRCS}
    ${VMP_SRCS}

    # ---- AI model (generated by STM32Cube.AI) ----
    ${CMAKE_SOURCE_DIR}/Model/${BOARD}/network.c
    ${CMAKE_SOURCE_DIR}/Model/${BOARD}/stai_network.c

    # ---- STEdge AI NPU device support ----
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/Devices/STM32N6xx/mcu_cache.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/Devices/STM32N6xx/npu_cache.c

    # ---- ll_aton runtime ----
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_rt_main.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_runtime.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_cipher.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_stai_internal.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_util.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_sw_float.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_sw_integer.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_lib.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Npu/ll_aton/ll_aton_lib_sw_operators.c

    # ---- HAL ----
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/CMSIS/Device/ST/STM32N6xx/Source/Templates/system_stm32n6xx_fsbl.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_cortex.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_dcmipp.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_dma2d.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_gpio.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_uart.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_i2c.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_i2c_ex.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_ltdc.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_ltdc_ex.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_rif.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_ramcfg.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_cacheaxi.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_pwr.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_pwr_ex.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_rcc.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_rcc_ex.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_xspi.c
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_bsec.c

    # ---- Camera middleware (sensors + wrappers) ----
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/cmw_camera.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/cmw_utils.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/imx335/imx335.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/imx335/imx335_reg.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/vd6g/vd6g.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/vd55g1/vd55g1.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/vd1943/vd1943.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/ov5640/ov5640.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/ov5640/ov5640_reg.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/cmw_vd55g1.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/cmw_vd66gy.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/cmw_imx335.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/cmw_vd1943.c
    ${CMAKE_SOURCE_DIR}/Middlewares/stm32-mw-camera/sensors/cmw_ov5640.c

    # ---- ISP library ----
    ${ISP_SRCS}

    # ---- LCD utility ----
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Utilities/lcd/stm32_lcd.c

    # ---- Startup assembly ----
    ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/CMSIS/Device/ST/STM32N6xx/Source/Templates/gcc/startup_stm32n657xx_fsbl.s
)

# ---------------------------------------------------------------
# Board-specific configuration
# ---------------------------------------------------------------
if(BOARD STREQUAL "STM32N6570-DK")

    target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6570-DK
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/mx66uw1g45g
    )

    target_sources(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6570-DK/stm32n6570_discovery.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6570-DK/stm32n6570_discovery_bus.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6570-DK/stm32n6570_discovery_lcd.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6570-DK/stm32n6570_discovery_xspi.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/mx66uw1g45g/mx66uw1g45g.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/aps256xx/aps256xx.c
    )

elseif(BOARD STREQUAL "NUCLEO-N657X0-Q")

    # Display mode: UVCL (USB-UVC, default) or SPI (ILI9341 over SPI)
    if(NOT DEFINED NUCLEO_DISPLAY)
        set(NUCLEO_DISPLAY "UVCL" CACHE STRING
            "NUCLEO display interface: UVCL or SPI")
    endif()
    message(STATUS "Display : ${NUCLEO_DISPLAY}")

    target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
        STM32N6570_NUCLEO_REV
    )

    target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6xx_Nucleo
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/mx25um51245g
        ${CMAKE_SOURCE_DIR}/Middlewares/screenl/Inc
    )

    target_sources(${CMAKE_PROJECT_NAME} PRIVATE
        # BSP Nucleo
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6xx_Nucleo/stm32n6xx_nucleo.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6xx_Nucleo/stm32n6xx_nucleo_bus.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/STM32N6xx_Nucleo/stm32n6xx_nucleo_xspi.c
        # NOR flash component
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/mx25um51245g/mx25um51245g.c
        # PSRAM component
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/BSP/Components/aps256xx/aps256xx.c
        # Additional HAL modules needed by USB/SPI display
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_spi.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_dma.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_dma_ex.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_pcd.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_hal_pcd_ex.c
        ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Drivers/STM32N6xx_HAL_Driver/Src/stm32n6xx_ll_usb.c
    )

    # Screen library — UVCL mode (USB Video Class, via Azure USBX)
    if(NUCLEO_DISPLAY STREQUAL "UVCL")
        set(USBX_DIR
            ${CMAKE_SOURCE_DIR}/STM32Cube_FW_N6/Middlewares/ST/usbx)

        file(GLOB USBX_SYSTEM_SRCS
            ${USBX_DIR}/common/core/src/ux_system_*.c)
        file(GLOB USBX_UTILITY_SRCS
            ${USBX_DIR}/common/core/src/ux_utility_*.c)
        file(GLOB USBX_DEVICE_CORE_SRCS
            ${USBX_DIR}/common/core/src/ux_device_*.c)
        file(GLOB USBX_DCD_SRCS
            ${USBX_DIR}/common/usbx_stm32_device_controllers/ux_dcd_stm32_*.c)
        file(GLOB USBX_VIDEO_SRCS
            ${USBX_DIR}/common/usbx_device_classes/src/ux_device_class_video_*.c)

        target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
            SCR_LIB_USE_UVCL
            SCR_LIB_USE_NONE        # RTOS = NONE (bare-metal)
            UVC_LIB_USE_USBX
            UX_INCLUDE_USER_DEFINE_FILE
            "USBL_PACKET_PER_MICRO_FRAME=3"
            UX_STANDALONE               # bare-metal USBX mode
        )

        target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
            ${USBX_DIR}/common/core/inc
            ${USBX_DIR}/ports/generic/inc
            ${USBX_DIR}/common/usbx_device_classes/inc
            ${USBX_DIR}/common/usbx_stm32_device_controllers
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/uvcl/Inc
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/uvcl/Inc/usbx
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/uvcl/Src/usbx
        )

        target_sources(${CMAKE_PROJECT_NAME} PRIVATE
            # screenl UVCL sources
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/Src/scrl_usb.c
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/Src/scrl_common.c
            # uvcl library
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/uvcl/Src/uvcl.c
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/uvcl/Src/uvcl_desc.c
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/uvcl/Src/usbx/uvcl_usbx.c
            # USBX stack
            ${USBX_SYSTEM_SRCS}
            ${USBX_UTILITY_SRCS}
            ${USBX_DEVICE_CORE_SRCS}
            ${USBX_DCD_SRCS}
            ${USBX_VIDEO_SRCS}
        )

    elseif(NUCLEO_DISPLAY STREQUAL "SPI")
        target_compile_definitions(${CMAKE_PROJECT_NAME} PRIVATE
            SCR_LIB_USE_SPI
            SCR_LIB_USE_NONE        # RTOS = NONE (bare-metal)
        )

        target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/ili9341
        )

        target_sources(${CMAKE_PROJECT_NAME} PRIVATE
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/Src/scrl_spi.c
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/Src/scrl_common.c
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/ili9341/ili9341_reg.c
            ${CMAKE_SOURCE_DIR}/Middlewares/screenl/ili9341/ili9341.c
        )

    else()
        message(FATAL_ERROR
            "Unknown NUCLEO_DISPLAY '${NUCLEO_DISPLAY}'. Use UVCL or SPI")
    endif()

endif()

# ---------------------------------------------------------------
# AI runtime library
# ---------------------------------------------------------------
target_link_directories(${CMAKE_PROJECT_NAME} PRIVATE
    ${CMAKE_SOURCE_DIR}/Middlewares/stedgeai-lib/Lib/GCC/ARMCortexM55)

target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE
    :NetworkRuntime1200_CM55_GCC.a
    c m nosys)

# ---------------------------------------------------------------
# Post-build: generate .bin and print size
# ---------------------------------------------------------------
add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_OBJCOPY} -O binary $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
            ${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}.bin
    COMMENT "Generating binary: ${CMAKE_PROJECT_NAME}.bin"
)
add_custom_command(TARGET ${CMAKE_PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_SIZE} $<TARGET_FILE:${CMAKE_PROJECT_NAME}>
    COMMENT "ELF size:"
)
