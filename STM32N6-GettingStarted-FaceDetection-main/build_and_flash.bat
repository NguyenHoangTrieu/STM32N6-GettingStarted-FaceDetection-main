@echo off
setlocal EnableDelayedExpansion
title STM32N6 FaceDetection — Build and Flash

:: ---------------------------------------------------------------
:: Tool paths  (edit if installed in non-default locations)
:: ---------------------------------------------------------------
set PROG_PATH=C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin
set PROGRAMMER="%PROG_PATH%\STM32_Programmer_CLI.exe"
set SIGNER=STM32_SigningTool_CLI.exe
set OBJCOPY=arm-none-eabi-objcopy.exe

:: ---------------------------------------------------------------
:: Board selection menu
:: ---------------------------------------------------------------
echo.
echo ========================================================
echo  STM32N6 FaceDetection — Build and Flash
echo ========================================================
echo.
echo  1. STM32N6570-DK        (LTDC display)
echo  2. NUCLEO-N657X0-Q      (UVCL USB-UVC display)
echo  3. NUCLEO-N657X0-Q      (SPI ILI9341 display)
echo.
set /p CHOICE="Select board [1-3]: "

if "%CHOICE%"=="1" (
    set BOARD=STM32N6570-DK
    set PRESET=DK-Release
    set EXT_LOADER=MX66UW1G45G_STM32N6570-DK.stldr
    goto CONFIG_DONE
)
if "%CHOICE%"=="2" (
    set BOARD=NUCLEO-N657X0-Q
    set PRESET=NUCLEO-UVCL-Release
    set EXT_LOADER=MX25UM51245G_STM32N6570-NUCLEO.stldr
    goto CONFIG_DONE
)
if "%CHOICE%"=="3" (
    set BOARD=NUCLEO-N657X0-Q
    set PRESET=NUCLEO-SPI-Release
    set EXT_LOADER=MX25UM51245G_STM32N6570-NUCLEO.stldr
    goto CONFIG_DONE
)

echo [ERROR] Invalid choice.
goto END

:CONFIG_DONE
set BUILD_DIR=build\%PRESET%
set TARGET=FaceDetection_%BOARD%
set ELF=%BUILD_DIR%\%TARGET%.elf
set BIN=%BUILD_DIR%\%TARGET%.bin
set BIN_SIGNED=%BUILD_DIR%\%TARGET%_signed.bin
set FSBL_HEX=FSBL\ai_fsbl.hex
set NETWORK_DATA=Model\%BOARD%\network_data.xSPI2.bin

echo.
echo  Board   : %BOARD%
echo  Preset  : %PRESET%
echo  Loader  : %EXT_LOADER%
echo.

:: ---------------------------------------------------------------
:: Step 1 — Clean, configure, build
:: ---------------------------------------------------------------
if exist "%BUILD_DIR%" (
    echo [1/5] Cleaning previous build: %BUILD_DIR%
    rmdir /s /q "%BUILD_DIR%"
)

echo [1/5] Configuring with CMake preset "%PRESET%"...
cmake --preset %PRESET% .
if errorlevel 1 (
    echo [ERROR] CMake configure failed.
    goto END
)

echo [1/5] Building...
cmake --build --preset %PRESET%
if errorlevel 1 (
    echo [ERROR] Build failed.
    goto END
)

if not exist "%ELF%" (
    echo [ERROR] ELF not found: %ELF%
    goto END
)

:: ---------------------------------------------------------------
:: Step 2 — Sign the application binary
:: ---------------------------------------------------------------
echo [2/5] Signing: %BIN% -^> %BIN_SIGNED%
if not exist "%BIN%" (
    echo [ERROR] Binary not found: %BIN%
    goto END
)

%SIGNER% -s -bin "%BIN%" -nk -t ssbl -hv 2.3 -align -o "%BIN_SIGNED%"
if errorlevel 1 (
    echo [ERROR] Signing failed.
    goto END
)

:: ---------------------------------------------------------------
:: Step 3 — Flash FSBL
:: ---------------------------------------------------------------
if not exist "%FSBL_HEX%" (
    echo [ERROR] FSBL not found: %FSBL_HEX%
    goto END
)

echo [3/5] Flashing FSBL: %FSBL_HEX%
%PROGRAMMER% -c port=swd mode=HOTPLUG -hardRst ^
    -el "%PROG_PATH%\ExternalLoader\%EXT_LOADER%" ^
    -w "%FSBL_HEX%"
if errorlevel 1 (
    echo [ERROR] FSBL flash failed.
    goto END
)

:: ---------------------------------------------------------------
:: Step 4 — Flash signed application @ 0x70100000
:: ---------------------------------------------------------------
echo [4/5] Flashing application @ 0x70100000: %BIN_SIGNED%
%PROGRAMMER% -c port=swd mode=HOTPLUG -hardRst ^
    -el "%PROG_PATH%\ExternalLoader\%EXT_LOADER%" ^
    -w "%BIN_SIGNED%" 0x70100000
if errorlevel 1 (
    echo [ERROR] Application flash failed.
    goto END
)

:: ---------------------------------------------------------------
:: Step 5 — Flash AI network weights @ 0x70380000
::          (model weights live in xSPI2, separate from app binary)
:: ---------------------------------------------------------------
if not exist "%NETWORK_DATA%" (
    echo [ERROR] Network data not found: %NETWORK_DATA%
    goto END
)

echo [5/5] Flashing network weights @ 0x70380000: %NETWORK_DATA%
%PROGRAMMER% -c port=swd mode=HOTPLUG -hardRst ^
    -el "%PROG_PATH%\ExternalLoader\%EXT_LOADER%" ^
    -w "%NETWORK_DATA%" 0x70380000
if errorlevel 1 (
    echo [ERROR] Network data flash failed.
    goto END
)

echo.
echo ========================================================
echo  Done! Board: %BOARD%
echo ========================================================
echo.

:END
endlocal
pause
