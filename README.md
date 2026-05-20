# STM32N6 Getting Started — Face Detection (CMake Build)

Port của project **STM32N6-GettingStarted-FaceDetection** từ STM32CubeIDE sang hệ thống build **CMake + Ninja**, với script tự động build và flash một lệnh duy nhất.

---

## Mục lục

1. [Yêu cầu](#yêu-cầu)
2. [Cấu trúc project](#cấu-trúc-project)
3. [Từ CubeIDE sang CMake — những gì thay đổi](#từ-cubeide-sang-cmake--những-gì-thay-đổi)
4. [Quy trình boot của STM32N6 và tại sao flash theo đúng thứ tự](#quy-trình-boot-của-stm32n6-và-tại-sao-flash-theo-đúng-thứ-tự)
5. [Cách build và flash](#cách-build-và-flash)
6. [Các lỗi đã tìm ra và sửa](#các-lỗi-đã-tìm-ra-và-sửa)

---

## Yêu cầu

| Công cụ | Phiên bản tối thiểu | Ghi chú |
|---|---|---|
| CMake | 3.22 | |
| Ninja | bất kỳ | generator mặc định |
| arm-none-eabi-gcc | 12.x | phải có trong PATH |
| STM32CubeProgrammer | 2.x | `STM32_Programmer_CLI.exe` phải có trong PATH hoặc đặt đúng `PROG_PATH` trong bat |
| STM32_SigningTool_CLI | 2.x | phải có trong PATH |

---

## Cấu trúc project

```
├── CMakeLists.txt              # Build definition chính
├── CMakePresets.json           # Các preset: DK-Release, NUCLEO-UVCL-Release, ...
├── gcc-arm-none-eabi.cmake     # Toolchain file cho cross-compile
├── build_and_flash.bat         # Script build + sign + flash tự động (Windows)
│
├── Application/
│   ├── STM32N6570-DK/          # Source, headers, linker script cho DK board
│   └── NUCLEO-N657X0-Q/        # Source, headers, linker script cho Nucleo board
│
├── FSBL/
│   └── ai_fsbl.hex             # Pre-built First Stage Boot Loader (nhị phân cố định)
│
├── Model/
│   ├── STM32N6570-DK/
│   │   ├── network_ecblobs.h       # Epoch Controller blob (nhúng trong app)
│   │   └── network_data.xSPI2.bin  # Trọng số mạng nơ-ron (flash riêng)
│   └── NUCLEO-N657X0-Q/
│
└── Middlewares/
    └── stedgeai-lib/           # ST Edge AI runtime library (.a)
```

---

## Từ CubeIDE sang CMake — những gì thay đổi

### Lý do chuyển đổi

STM32CubeIDE (Eclipse-based) quản lý build thông qua `.cproject` và `.project` — các file XML khó đọc, khó merge khi dùng git, và không tích hợp được với CI/CD hay các editor khác như VS Code. CMake giải quyết toàn bộ những vấn đề đó.

### Những file quan trọng được thêm vào

**`gcc-arm-none-eabi.cmake`** — Toolchain file, thay thế hoàn toàn phần cấu hình compiler trong CubeIDE:

```cmake
set(CMAKE_SYSTEM_NAME Generic)        # bare-metal, không có OS
set(CMAKE_SYSTEM_PROCESSOR ARM)
set(CMAKE_C_COMPILER arm-none-eabi-gcc)

set(COMMON_FLAGS
    "${STM32_MCU_FLAGS} -Os -g3 -Wall -fstack-usage \
     -fdata-sections -ffunction-sections")

set(CMAKE_EXE_LINKER_FLAGS_INIT
    "-specs=nano.specs \
     -T <linker_script.ld> \
     -Wl,--gc-sections ...")
```

Các flag này được lấy trực tiếp từ `Application/<BOARD>/Makefile` của project gốc để đảm bảo tương đương hoàn toàn.

**`CMakePresets.json`** — Định nghĩa sẵn các cấu hình build:

```json
{
  "name": "DK-Release",
  "generator": "Ninja",
  "binaryDir": "${sourceDir}/build/DK-Release",
  "cacheVariables": { "BOARD": "STM32N6570-DK", "CMAKE_BUILD_TYPE": "Release" }
}
```

Mỗi preset tương ứng với một board và chế độ build. Không cần nhớ flag `-D`.

**`CMakeLists.txt`** — Giữ nguyên toàn bộ:
- Danh sách source file (giống hệt Makefile gốc)
- Compile definitions (`STM32N657xx`, `USE_FULL_ASSERT`, `LL_ATON_*`, ...)
- Linker script: `Application/${BOARD}/STM32CubeIDE/STM32N657xx.ld` (dùng chung file .ld với CubeIDE)
- Thư viện: `NetworkRuntime1200_CM55_GCC.a`, `c`, `m`, `nosys`
- Post-build: `arm-none-eabi-objcopy -O binary <ELF> <BIN>`

### Những gì KHÔNG thay đổi

- Linker script `.ld` — dùng nguyên bản từ CubeIDE, không sửa
- Source code C — không thay đổi một dòng nào
- Startup file: `startup_stm32n657xx_fsbl.s` và `system_stm32n6xx_fsbl.c`
- Thư viện AI runtime
- FSBL binary (`ai_fsbl.hex`) — pre-built, cố định

---

## Quy trình boot của STM32N6 và tại sao flash theo đúng thứ tự

STM32N6 sử dụng kiến trúc **LRUN** (Load and Run): ứng dụng không chạy trực tiếp từ flash mà được copy vào SRAM trước khi chạy. Quá trình boot gồm hai tầng:

```
Power On
    │
    ▼
[Boot ROM]  (bên trong chip, bất biến)
    │  Đọc header từ 0x70000000 (NOR flash sector 0)
    │  Xác thực → nhảy vào FSBL
    ▼
[FSBL — First Stage Boot Loader]  @ 0x70000000 (NOR flash)
    │  Đọc signed app header từ 0x70100000
    │  Xác thực chữ ký header v2.3
    │  Copy payload → AXISRAM1_S @ 0x34000400
    │  Đọc entry point từ header → nhảy vào app
    ▼
[Application]  @ 0x34000400 (AXISRAM1_S, tốc độ cao)
    │  Hardware_init(), NeuralNetwork_init()
    │  Load network weights từ 0x70380000 (NOR flash XIP)
    │  Camera → NPU inference → Display
```

### Bố cục NOR flash (MX66UW1G45G, sector 64 KB)

| Địa chỉ | Nội dung | File |
|---|---|---|
| `0x70000000` | FSBL (First Stage Boot Loader) | `FSBL/ai_fsbl.hex` |
| `0x70100000` | Signed application (header + payload) | `*_signed.bin` |
| `0x70380000` | Network weights (tflite model data) | `network_data.xSPI2.bin` |

Đây là lý do script flash 3 vùng riêng biệt (bước 3, 4, 5) thay vì flash một file duy nhất: mỗi vùng có nguồn gốc khác nhau và không phụ thuộc lẫn nhau khi update.

### Cơ chế ký số (Signing) — Header v2.3

Trước khi flash, file `.bin` phải được ký bằng `STM32_SigningTool_CLI`:

```
[1024 bytes — Signing Header v2.3]   ← magic, checksum, size, entry point
[Padding bytes]                       ← do flag -align tạo ra
[Application binary payload]          ← nội dung ELF → objcopy -O binary
```

FSBL đọc header tại `0x70100000`, lấy:
- **Size**: số byte cần copy
- **Entry point**: địa chỉ Reset_Handler để nhảy vào sau khi copy xong
- Copy payload từ `0x70100400` (sau header) vào `0x34000400`
- Nhảy đến entry point trong AXISRAM1_S

---

## Cách build và flash

### Chạy script tự động (Windows)

```bat
build_and_flash.bat
```

Script sẽ hỏi chọn board rồi tự động thực hiện 5 bước:

```
[1/5] CMake configure + build  (cmake --preset DK-Release)
[2/5] Sign binary              (STM32_SigningTool_CLI -s -bin ... -nk -t ssbl -hv 2.3 -align)
[3/5] Flash FSBL               (@ 0x70000000)
[4/5] Flash signed app         (@ 0x70100000)
[5/5] Flash network weights    (@ 0x70380000)
```

### Build thủ công (không flash)

```bash
# Configure
cmake --preset DK-Release

# Build
cmake --build --preset DK-Release

# Output: build/DK-Release/FaceDetection_STM32N6570-DK.elf
#         build/DK-Release/FaceDetection_STM32N6570-DK.bin
```

### Chỉ flash (đã build rồi)

Bỏ qua bước build, chạy trực tiếp từ `build/DK-Release/`:

```bat
STM32_SigningTool_CLI.exe -s -bin FaceDetection_STM32N6570-DK.bin ^
    -nk -t ssbl -hv 2.3 -align -o FaceDetection_STM32N6570-DK_signed.bin

STM32_Programmer_CLI.exe -c port=swd mode=HOTPLUG -hardRst ^
    -el "ExternalLoader\MX66UW1G45G_STM32N6570-DK.stldr" ^
    -w FSBL\ai_fsbl.hex

STM32_Programmer_CLI.exe -c port=swd mode=HOTPLUG -hardRst ^
    -el "ExternalLoader\MX66UW1G45G_STM32N6570-DK.stldr" ^
    -w FaceDetection_STM32N6570-DK_signed.bin 0x70100000

STM32_Programmer_CLI.exe -c port=swd mode=HOTPLUG -hardRst ^
    -el "ExternalLoader\MX66UW1G45G_STM32N6570-DK.stldr" ^
    -w Model\STM32N6570-DK\network_data.xSPI2.bin 0x70380000
```

---

## Các lỗi đã tìm ra và sửa

### Lỗi 1 (Nghiêm trọng) — Thiếu flag `-align` khi ký binary

**Triệu chứng:** Board không hiển thị gì, không có log, không hoạt động. Firmware mẫu (pre-built trong `Binary/`) chạy bình thường nhưng bản CMake build không chạy.

**Nguyên nhân gốc rễ:**

`STM32_SigningTool_CLI` với header v2.3 có flag `-align` **bắt buộc** cho STM32N6 nhưng không có trong lệnh signing ban đầu.

Khi không có `-align`, signing tool đọc entry point từ **sai offset** trong binary — cụ thể là `offset 0x40` (vùng IRQ0 của vector table = `Default_Handler`) thay vì `offset 0x04` (`Reset_Handler`). Kết quả:

| | Địa chỉ Entry Point | Hàm tương ứng |
|---|---|---|
| Binary mẫu (có `-align`) | `0x3401C031` | `Reset_Handler` ✓ |
| Binary CMake **không có** `-align` | `0x34020185` | `Default_Handler` ✗ |
| Binary CMake **có** `-align` | `0x34020129` | `Reset_Handler` ✓ |

FSBL đọc entry point từ header và nhảy đến địa chỉ đó. Khi entry point trỏ vào `Default_Handler` (vòng lặp `while(1)` vô tận hoặc `BKPT`), board đứng im ngay từ đầu.

Flag `-align` còn đảm bảo payload được căn chỉnh bắt đầu từ **offset 0x400** (1024 bytes) tính từ đầu file ký — đúng với cấu trúc mà FSBL mong đợi:

```
Trước fix:   [Header 604 bytes][Payload bắt đầu @ offset 604]  ← entry point sai
Sau fix:     [Header + padding = 1024 bytes][Payload bắt đầu @ offset 0x400]  ← entry point đúng
```

**Fix:**

```bat
:: Trước (sai):
STM32_SigningTool_CLI.exe -s -bin "%BIN%" -nk -t ssbl -hv 2.3 -o "%BIN_SIGNED%"

:: Sau (đúng):
STM32_SigningTool_CLI.exe -s -bin "%BIN%" -nk -t ssbl -hv 2.3 -align -o "%BIN_SIGNED%"
```

---

### Lỗi 2 (Sai hướng điều tra, đã revert) — ECBLOB_CONST_SECTION

**Triệu chứng ban đầu tưởng:** Network blob `_ec_blob_network_1` cần đặt ở flash thay vì SRAM.

**Phân tích:** Phân tích binary mẫu (`Binary/STM32N6570-DK/...hex`) bằng cách parse từng segment của HEX file. Kết quả:

```
Segment 0x70000000: 62,752 bytes  → FSBL
Segment 0x70100000: 384,832 bytes → Signed application (payload trong AXISRAM1_S)
Segment 0x70380000: 108,520 bytes → Network weights
```

Không có segment nào tại `0x71380000` (địa chỉ `.flash_section`). Điều này chứng minh binary mẫu đặt ecblob trong `.rodata` ở AXISRAM1_S — **giống hệt** cách CMake build mà không cần define `ECBLOB_CONST_SECTION`. Mọi thay đổi liên quan đến `ECBLOB_CONST_SECTION` đã được revert hoàn toàn.

---

### Xác nhận các thành phần không phải nguyên nhân lỗi

Trong quá trình debug, các yếu tố sau đã được xác nhận **không phải nguyên nhân**:

| Yếu tố | Kết luận |
|---|---|
| FSBL (`ai_fsbl.hex`) | Byte-identical với segment FSBL trong binary mẫu ✓ |
| Network weights (`network_data.xSPI2.bin`) | Byte-identical với segment network trong binary mẫu ✓ |
| Startup file (`startup_stm32n657xx_fsbl.s`) | Đúng variant cho LRUN boot ✓ |
| Linker script | Dùng chung file `.ld` với CubeIDE ✓ |
| Memory map | AXISRAM1_S sử dụng 47%, không overflow ✓ |
| Vector table | SP = `0x34100000`, Reset = `0x34020129` ✓ |
| Source files | Danh sách file khớp hoàn toàn với Makefile gốc ✓ |
| Compiler flags | `-Os -g3 -mcpu=cortex-m55 -specs=nano.specs` — khớp Makefile gốc ✓ |
