# Change Report - FaceDetection CMake Migration

Date: 2026-05-19

Scope: migrate `STM32N6-GettingStarted-FaceDetection-main` from `STM32CubeIDE + Makefile` to `CMake + batch build/flash`, as required in `todo.md`.

## Quick summary

- `FSBL/ai_fsbl.hex` is the ST-provided prebuilt bootloader binary. It is used **as-is** — no source replacement is planned.
- The `FSBL/` folder contains only `ai_fsbl.hex` and `Release_Notes.md`; there is no FSBL source project in this package.
- `README.md` and both `stmaic_*.conf` files already reference this hex file for flashing the bootloader.
- The migration only touches the **application build system and flash automation**; the FSBL binary and application logic are left unchanged.
- `Camera_N6_AI_Test` is the reference for **top-level CMake structure and batch script**.

## 1. FSBL — `ai_fsbl.hex`

### Location

- `FSBL/ai_fsbl.hex`

### References in the project

- `README.md` — instructs flashing `FSBL/ai_fsbl.hex` before the application and network data.
- `stmaic_STM32N6570-DK.conf` — sets `fsbl_bin = "ai_fsbl.hex"`.
- `stmaic_NUCLEO-N657X0-Q.conf` — sets `fsbl_bin = "ai_fsbl.hex"`.
- `Doc/Boot-Overview.md` — describes the FSBL as the bootloader that loads the application from external flash into RAM and jumps to it.

### Decision

`FSBL/ai_fsbl.hex` is the ST-packaged FSBL binary. It is used directly in the flash step without modification. The batch script will flash it to `0x70000000` (external NOR base) before flashing the signed application.


## 2. Current build/flash architecture

### Application build groups

The project has two independent application build groups:

1. `Application/STM32N6570-DK/`
2. `Application/NUCLEO-N657X0-Q/`

Each group currently contains:

- `Makefile` — builds with `arm-none-eabi-gcc`
- `STM32CubeIDE/.project` and `.cproject`
- Linker script at `STM32CubeIDE/STM32N657xx.ld`

### Board-specific notes

#### STM32N6570-DK

- External NOR flash loader: `MX66UW1G45G_STM32N6570-DK.stldr`
- Single build configuration.

#### NUCLEO-N657X0-Q

- External NOR flash loader: `MX25UM51245G_STM32N6570-NUCLEO.stldr`
- `Makefile` has `SCR_LIB_SCREEN_ITF := UVCL` (can be switched to `SPI`).
- CubeIDE has two configurations: `UVCL_ModelZoo` and `SPI_ModelZoo`.

### Current flash sequence

1. Build application via `Makefile` or CubeIDE.
2. Sign the application binary: `STM32_SigningTool_CLI -t ssbl`.
3. Flash `FSBL/ai_fsbl.hex` to `0x70000000`.
4. Flash signed application binary to `0x70100000`.
5. Flash `Model/<board>/network_data.hex`.

## 3. Gap analysis vs `todo.md` requirements

Requirements to achieve:

1. Migrate from CubeIDE to **CMake + batch** for build and flash.
2. The batch script must let the user **choose the target board**.
3. Use `Camera_N6_AI_Test` as the reference for CMake structure and `build_and_flash.bat`.
4. Remove CubeIDE metadata files after the new system is validated.

### Feasibility

- **Ready now** — application CMake build system for both boards.
- **Ready now** — batch script with board selection and automated flash sequence.
- **No blocker** — `FSBL/ai_fsbl.hex` is used directly; no rebuild needed.

## 4. Reference project: `Camera_N6_AI_Test`

Used as reference for:

- Top-level `CMakeLists.txt` with `ExternalProject_Add` pattern.
- `gcc-arm-none-eabi.cmake` toolchain file.
- `build/`, `Appli/` sub-project organisation.
- `build_and_flash.bat` structure (board selection, sign, flash sequence).

The FSBL portion of `Camera_N6_AI_Test` is **not** used as a reference — that project has its own FSBL source; this migration uses the prebuilt `ai_fsbl.hex` instead.

## 5. Migration plan

Single-phase migration: convert the build system and flash automation while keeping all application source and `FSBL/ai_fsbl.hex` unchanged.

### Steps

1. Create top-level `CMakeLists.txt` at project root.
2. Add `gcc-arm-none-eabi.cmake` toolchain file.
3. Convert `Application/STM32N6570-DK/Makefile` sources, defines, and includes into a CMake target.
4. Convert `Application/NUCLEO-N657X0-Q/Makefile` sources, defines, and includes into a CMake target (with `UVCL`/`SPI` option).
5. Reuse the existing linker script `STM32CubeIDE/STM32N657xx.ld` from each board folder.
6. Create `build_and_flash.bat` with board selection:
   - `STM32N6570-DK`
   - `NUCLEO-N657X0-Q` (with optional `UVCL`/`SPI` argument)
7. Flash sequence in batch:
   - Build app via CMake/Ninja
   - Sign app: `STM32_SigningTool_CLI -t ssbl`
   - Flash `FSBL/ai_fsbl.hex`
   - Flash signed app to `0x70100000`
   - Flash `Model/<board>/network_data.hex`
8. Validate full build + flash on at least one board.
9. Remove CubeIDE metadata files after validation.

## 6. Expected file changes

### New files

| File | Purpose |
|------|---------|
| `CMakeLists.txt` | Top-level CMake; board selected via `-DBOARD=` |
| `gcc-arm-none-eabi.cmake` | ARM toolchain file |
| `build_and_flash.bat` | Build + sign + flash automation with board selection |
| `cmake/STM32N6570-DK.cmake` | DK-specific sources, defines, includes |
| `cmake/NUCLEO-N657X0-Q.cmake` | Nucleo-specific sources, defines, includes |

### Kept unchanged

| Item | Reason |
|------|--------|
| `FSBL/ai_fsbl.hex` | Used directly as the bootloader binary |
| `FSBL/Release_Notes.md` | Reference documentation |
| `Application/.../Src` and `Inc` | Application source — not modified |
| `Application/.../STM32CubeIDE/STM32N657xx.ld` | Reused by CMake as the linker script |
| `Model/...` | Network data and model files — not modified |
| `Middlewares/...` | Not modified |
| `STM32Cube_FW_N6/...` | Not modified |

### Removed after validation

| File | Condition |
|------|-----------|
| `Application/STM32N6570-DK/STM32CubeIDE/.project` | After CMake build is confirmed working |
| `Application/STM32N6570-DK/STM32CubeIDE/.cproject` | After CMake build is confirmed working |
| `Application/NUCLEO-N657X0-Q/STM32CubeIDE/.project` | After CMake build is confirmed working |
| `Application/NUCLEO-N657X0-Q/STM32CubeIDE/.cproject` | After CMake build is confirmed working |
| `Application/STM32N6570-DK/Makefile` | After CMake build is confirmed working |
| `Application/NUCLEO-N657X0-Q/Makefile` | After CMake build is confirmed working |

Note: the linker scripts inside `STM32CubeIDE/` are kept — CMake references them directly.

## 7. Open questions

1. For NUCLEO-N657X0-Q, should the batch default to `UVCL` mode, or always ask the user to specify `UVCL`/`SPI`?
2. Confirm `NUCLEO-N657X0-Q` is the correct board name (the `todo.md` had a possible typo `NUCLEO-N67X0-Q`).

## 8. Implementation checkpoints

| # | Checkpoint | Acceptance |
|---|-----------|-----------|
| 1 | CMake builds `STM32N6570-DK` application | `.elf` produced, no linker errors |
| 2 | CMake builds `NUCLEO-N657X0-Q` application (UVCL) | `.elf` produced, no linker errors |
| 3 | `build_and_flash.bat` board selection works | Correct ELF produced per board argument |
| 4 | Full flash sequence runs: FSBL + app + network data | Device boots after flash |
| 5 | CubeIDE metadata and Makefiles removed | Clean repo, no IDE-specific files |

