# Framos Drivers vs L4T OOT Modules - Source Differences

## Overview

This document outlines the differences between a part of the original L4T OOT modules from Nvidia and the Framos drivers source code.

## Directory Structure

Both sources follow the same folder structure under `source/`:

```
source/
├── hardware/          # Device tree hardware support
├── hwpm/              # Hardware Performance Monitoring
├── kernel-devicetree/ # Device tree compilation
├── nvethernetrm/      # Ethernet RM
└── nvidia-oot/        # NVIDIA Out-of-Tree modules (largest diff)
```

## Key Differences

### 1. **Root Level Makefile** (Simplified for Framos drivers)
- **Location**: `source/Makefile`
- **Status**: Present in both L4T and Framos, but **significantly simplified in Framos**
- **Framos Makefile is stripped down to camera/OOT drivers only**:

| Target | L4T | Framos | Notes |
|--------|-----|--------|-------|
| `help` | ✓ | ✓ | Framos text is slightly different |
| `modules` | ✓ (hwpm, nvidia-oot, nvgpu, nvidia-display) | ✓ (hwpm, modules only) | Framos renames `nvidia-oot:` to `modules:` |
| `dtbs` | ✓ (nvidia-dtbs) | ✓ (dtbs) | Framos renames `nvidia-dtbs:` to `dtbs:` |
| `modules_install` | ✓ (+ nvidia-display-install) | ✓ (+ `@sudo depmod -a`) | Framos adds depmod call |
| `clean` | ✓ | ✗ | **Removed in Framos** |
| `nvidia-headers` | ✓ | ✗ | **Removed in Framos** |
| `nvidia-display*` | ✓ (3 targets) | ✗ | **Removed entirely in Framos** |
| `nvgpu` | ✓ | ✗ | **Removed in Framos** |
| `nvidia-dtbs-clean` | ✓ | ✗ | **Removed in Framos** |

- **Removed 87 lines**: All nvgpu, nvdisplay, nvidia-display, and nvidia-headers build targets
- **Reason**: Framos drivers focus on camera support, not GPU or display drivers

### 2. **Device Tree Overlays** (Framos additions)
- **Location**: `hardware/nvidia/t23x/nv-public/overlay/`
- **Framos adds 192 device tree overlay files** (.dts) for various camera sensor configurations:
  - Multiple IMX sensor variants (IMX283, IMX296, IMX304, IMX335, IMX412, IMX464, IMX530, IMX565, IMX568, IMX577, IMX585, IMX636)
  - Different lane configurations (1-lane, 2-lane, 4-lane)
  - Multiple CSI port combinations (j5, j6, j7, j8)
  - Example: `tegra234-p3737-camera-fr_imx283-j5-4lane-overlay.dts`

**Impact**: The overlay Makefile is modified to include these additional DTBO targets.

### 3. **Framos Camera Sensor Drivers** (New files in nvidia-oot)
- **Location**: `nvidia-oot/drivers/media/i2c/` and `nvidia-oot/drivers/i2c/`
- **Added files** (~41,968 lines of code total):
  - Driver implementations:
    - `fr_imx283.c` / `fr_imx283_mode_tbls.h`
    - `fr_imx296.c` / `fr_imx296_mode_tbls.h`
    - `fr_imx304.c` / `fr_imx304_mode_tbls.h`
    - `fr_imx335.c` / `fr_imx335_mode_tbls.h`
    - `fr_imx412.c` / `fr_imx412_mode_tbls.h`
    - `fr_imx464.c` / `fr_imx464_mode_tbls.h`
    - `fr_imx530.c` / `fr_imx530_mode_tbls.h`
    - `fr_imx565.c` / `fr_imx565_mode_tbls.h`
    - `fr_imx568.c` / `fr_imx568_mode_tbls.h`
    - `fr_imx577.c` / `fr_imx577_mode_tbls.h`
    - `fr_imx585.c` / `fr_imx585_mode_tbls.h`
    - `fr_imx636.c` / `fr_imx636_mode_tbls.h`
    - `fr_imx662.c` / `fr_imx662_mode_tbls.h`
    - `fr_imx675.c` / `fr_imx675_mode_tbls.h`
    - `fr_imx676.c` / `fr_imx676_mode_tbls.h`
    - `fr_imx678.c` / `fr_imx678_mode_tbls.h`
    - `fr_imx715.c` / `fr_imx715_mode_tbls.h`
    - `fr_imx838.c` / `fr_imx838_mode_tbls.h`
    - `fr_imx900.c` / `fr_imx900_mode_tbls.h`
  - Bridge/converter drivers:
    - `fr_lifcl_var2fixed_1.c`
    - `fr_lifmd_lvds2mipi_1.c`
  - Serializer/Deserializer:
    - `fr_max96792.c`
    - `fr_max96793.c`
  - Common utilities:
    - `fr_sensor_common.c`
  - Generic I2C driver:
    - `drivers/i2c/fr_i2c_generic.c` (122 lines) - Generic I2C register access utilities

### 4. **Camera Core Infrastructure Changes** (Modified files)
- **Location**: `nvidia-oot/include/media/` and `nvidia-oot/drivers/media/platform/tegra/camera/`
- **Modified header files**:
  - `include/media/camera_common.h` - Added Framos-specific structures and callbacks
  - `include/media/tegra-v4l2-camera.h`
  - `include/media/tegra_camera_core.h`
  - `include/media/vi.h`

- **Key additions to camera_common.h**:
  - New `struct reg_32` for 32-bit register operations
  - New camera_common_pdata fields:
    - `unsigned int xmaster_gpio` - External master GPIO
    - `char *gmsl` - GMSL (Gigabit Multimedia Serial Link) configuration
    - `bool has_color_filter` - Color filter flag
  - New regmap utility functions for 32-bit registers
  - New camera_common_ops callbacks:
    - `write_reg_32()` / `read_reg_32()` - 32-bit register access
    - `check_unsupported_mode()` - Validate video mode
    - `after_set_pixel_format()` - Post-format callback
    - `init_private_controls()` - Custom control initialization
  - New tegracam_sensor_data callback:
    - `set_digital_gain()` - Digital gain control

- **Modified source files**:
  - `drivers/media/platform/tegra/camera/camera_common.c`
  - `drivers/media/platform/tegra/camera/regmap_util.c`
  - `drivers/media/platform/tegra/camera/sensor_common.c`
  - `drivers/media/platform/tegra/camera/tegracam_ctrls.c`
  - `drivers/media/platform/tegra/camera/tegracam_v4l2.c`
  - `drivers/media/platform/tegra/camera/vi/channel.c`
  - `drivers/media/platform/tegra/camera/vi/vi5_fops.c`

### 5. **New Include Directories** (Framos additions)
- **Location**: `nvidia-oot/include/`
- **New directories**:
  - `i2c/` - I2C device headers for Framos sensors
- **New media headers**:
  - `fr_lifcl_var2fixed_1.h`
  - `fr_lifmd_lvds2mipi_1.h`
  - `fr_max96792.h`
  - `fr_max96793.h`
  - `fr_sensor_common.h`

### 6. **Ethernet Driver** (Shared between both)
- **Location**: `nvethernetrm/` at source root, symlinked to `nvidia-oot/drivers/net/ethernet/nvidia/nvethernet/nvethernetrm/`
- **Status**: Present in both L4T OOT modules and Framos drivers
- **Note**: In jetpack-nixos `oot-modules.nix`, the symlink is created during the build via `runCommand`

## Summary Table

| Category | Type | Count | Details |
|----------|------|-------|---------|
| **New Sensor Drivers** | Files | 21 | IMX camera sensor drivers + bridges/serializers + i2c utils (19 IMX variants + 2 bridges + 2 serializers + 1 common) |
| **New i2c Directories** | 2 | `nvidia-oot/drivers/i2c/` and `nvidia-oot/include/i2c/` | Generic I2C utilities and headers |
| **New Media Headers** | Files | 5 | Framos-specific public headers (fr_*.h) |
| **Modified Headers** | Files | 4 | Core camera infrastructure (camera_common.h, tegra-v4l2-camera.h, tegra_camera_core.h, vi.h) |
| **Modified Source** | Files | 7 | Camera platform drivers (~604 diff lines total) |
| **Modified i2c Makefile** | File | 1 | Adds 20 new Framos sensor driver targets |
| **New DTB Overlays** | Files | 192 | Camera sensor device tree overlays (fr_*.dts) |
| **Root Makefile** | File | 1 | Simplified version (removed nvgpu, nvdisplay, nvidia-display targets) |
| **Unchanged Directories** | 4 | hwpm, kernel-devicetree, nvethernetrm (fully identical) |

## Source File Modifications Detail

### Modified Camera Platform Drivers (7 files, ~604 diff lines)

| File | Diff Lines | Key Changes |
|------|-----------|-------------|
| `tegracam_ctrls.c` | 303 | Adds digital gain control handling for Framos sensors |
| `sensor_common.c` | 103 | Extends sensor common utilities for Framos-specific operations |
| `vi/vi5_fops.c` | 43 | Adds embedded data handling for video capture (embedded data buffer zone, width/height tracking) |
| `regmap_util.c` | 83 | Adds 32-bit register read/write operations |
| `camera_common.c` | 33 | Adds support for additional color formats (SGBRG8, SGRBG8) and mode validation callbacks |
| `vi/channel.c` | 29 | Adds embedded data size calculations and pixel format handling |
| `tegracam_v4l2.c` | 10 | Minor updates for pixel format handling |

### Modified i2c Makefile

Adds module targets for 20 Framos drivers:
- 1 common module: `fr_common.o` (fr_sensor_common.c)
- 2 converter modules: `fr_lifcl_var2fixed_1.o`, `fr_lifmd_lvds2mipi_1.o`
- 2 serializer modules: `fr_max96792.o`, `fr_max96793.o`
- 19 sensor modules: 18 IMX variants + 1 generic sensor

## File Modification Impact

### Camera Framework Extensions
The modifications to the camera common infrastructure suggest Framos drivers:
- Use GMSL serializers/deserializers for camera links
- Support 32-bit register operations (beyond standard 8/16-bit)
- Implement digital gain control
- Support mode validation and pixel format post-processing
- Require custom control initialization

### Embedded Data Handling
Significant additions to `vi/vi5_fops.c` (43 diff lines) and `vi/channel.c` (29 diff lines) for embedded data processing:
- Embedded data buffer management (buffer zone size, offset calculations)
- Support for storing embedded data metadata (width/height) in video buffer
- Embedded data width/height tracking in `vb2_dc_buf` structure
- This suggests Framos sensors provide embedded metadata alongside pixel data

### Device Tree
The massive addition of camera overlay DTBs provides sensor-specific device tree bindings for:
- Different sensor models
- Multiple lane configurations
- Various CSI port assignments
- Board variants (p3737, p3767, p3768, p3740)

This allows runtime device tree configuration without recompiling the kernel.

## Integration Strategy

1. Keep L4T OOT modules as the base package
2. Create patches for the modified files
3. Add Framos sensor drivers as separate module additions
4. Use overlay mechanism for device tree additions
