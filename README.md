# framos-jetson-drivers-nix

NixOS module for integrating [FRAMOS Jetson camera sensor drivers](https://github.com/framosimaging/framos-jetson-drivers) with [jetpack-nixos](https://github.com/anduril/jetpack-nixos).

Instead of building the drivers as a standalone package, this module patches jetpack-nixos's `nvidia-oot-modules` and `devicetree` builds directly — Framos camera infrastructure changes, sensor drivers, and device tree overlays are compiled alongside the base L4T out-of-tree modules in a single pass.

## Prerequisites

- [jetpack-nixos](https://github.com/anduril/jetpack-nixos) configured for your Jetson device
- An aarch64-linux NixOS system (Jetson Orin family)

## Usage

Add both jetpack-nixos and this flake as inputs, then import both NixOS modules:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    jetpack-nixos.url = "github:anduril/jetpack-nixos";
    framos-jetson-drivers.url = "github:akiro-group/framos-jetson-drivers-nix";
  };

  outputs = { nixpkgs, jetpack-nixos, framos-jetson-drivers, ... }: {
    nixosConfigurations.my-jetson = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        jetpack-nixos.nixosModules.default
        framos-jetson-drivers.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Then configure both modules in your `configuration.nix`:

```nix
{
  hardware.nvidia-jetpack = {
    enable = true;
    som = "orin-agx";        # or "orin-nx", "orin-nano", etc.
    carrierBoard = "devkit";
  };

  hardware.framos-jetson-drivers = {
    enable = true;
    sensors = [
      {
        sensor = "imx678";
        port   = "cam0";
        lanes  = "2lane";
        fpa    = "a_p22";
      }
    ];
  };
}
```

## How it works

When `hardware.framos-jetson-drivers.enable = true`, the module:

1. **Extends `kernelPackagesOverlay`** to override two jetpack-nixos packages:
   - `nvidia-oot-modules` — applies Framos camera infrastructure patches and copies in new sensor driver source files, so they are built together with all other OOT modules
   - `devicetree` — adds Framos DTBO overlay sources and the extended overlay Makefile, so all device tree overlays (upstream + Framos) are compiled in one pass
2. **Selects sensor-specific DTBOs** via `hardware.nvidia-jetpack.flashScriptOverrides.additionalDtbOverlays` based on the `sensors` configuration
3. **Installs tools** (`jetson-config-camera-cli.py`, `jetson-config-camera.py`, `crosslink_configurator`)
4. **Installs firmware** (CrossLink FPGA firmware) via an activation script

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable FRAMOS camera sensor drivers |
| `sensors` | list | `[]` | Camera sensor configurations (see below) |

### `sensors` entries

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `sensor` | enum | — | Sensor model (see list below) |
| `port` | enum | — | AGX Orin: `j5` `j6` `j7` `j8` — Orin Nano/NX: `cam0` `cam1` |
| `lanes` | enum | — | `1lane`, `2lane`, or `4lane` |
| `fpa` | enum | — | AGX Orin: `4a_agx` or `4a_txa` — Orin Nano/NX: `a_p22` |
| `gmsl` | bool | `false` | Apply the GMSL overlay for this port |

Supported sensors: `imx283` `imx296` `imx304` `imx335` `imx412` `imx464` `imx530` `imx565` `imx568` `imx577` `imx585` `imx636` `imx662` `imx675` `imx676` `imx678` `imx715` `imx838` `imx900`

Invalid `sensor`/`port`/`lanes` combinations are caught at evaluation time.

## Examples

### Orin Nano / Orin NX — two sensors

```nix
hardware.framos-jetson-drivers = {
  enable = true;
  sensors = [
    { sensor = "imx678"; port = "cam0"; lanes = "2lane"; fpa = "a_p22"; }
    { sensor = "imx565"; port = "cam1"; lanes = "4lane"; fpa = "a_p22"; }
  ];
};
```

### AGX Orin — two sensors, one with GMSL

```nix
hardware.framos-jetson-drivers = {
  enable = true;
  sensors = [
    { sensor = "imx678"; port = "j5"; lanes = "4lane"; fpa = "4a_agx"; }
    { sensor = "imx662"; port = "j6"; lanes = "2lane"; fpa = "4a_agx"; gmsl = true; }
  ];
};
```
