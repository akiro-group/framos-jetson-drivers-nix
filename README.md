# framos-jetson-drivers-nix

NixOS flake for installing [FRAMOS Jetson camera sensor drivers](https://github.com/framosimaging/framos-jetson-drivers).

## Usage

Add the flake as an input and import the NixOS module:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    framos-jetson-drivers.url = "github:akiro-group/framos-jetson-drivers-nix";
  };

  outputs = { nixpkgs, framos-jetson-drivers, ... }: {
    nixosConfigurations.my-jetson = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        framos-jetson-drivers.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Then configure the module in your `configuration.nix`:

```nix
hardware.framos-jetson-drivers = {
  enable = true;

  # One of: "36.3", "36.4", "36.4.3", "36.4.4", "38.4"
  l4tVersion = "36.4.4";

  sensors = [
    {
      sensor = "imx678";
      port   = "cam0";
      lanes  = "2lane";
      fpa    = "a_p22";
    }
  ];
};
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable the module |
| `l4tVersion` | enum | `"36.4.4"` | L4T version; selects the upstream source branch |
| `sensors` | list | `[]` | Camera sensor configurations (see below) |

### `sensors` entries

| Field | Type | Description |
|-------|------|-------------|
| `sensor` | enum | Sensor model: `imx283` `imx296` `imx304` `imx335` `imx412` `imx464` `imx530` `imx565` `imx568` `imx577` `imx585` `imx636` `imx662` `imx675` `imx676` `imx678` `imx715` `imx838` `imx900` |
| `port` | enum | AGX Orin: `j5` `j6` `j7` `j8` — Orin Nano/NX: `cam0` `cam1` |
| `lanes` | enum | `1lane` `2lane` `4lane` (valid combinations depend on sensor and port) |
| `fpa` | enum | AGX Orin: `4a_agx` `4a_txa` — Orin Nano/NX: `a_p22` |
| `gmsl` | bool | `false` | Apply the GMSL overlay for this port |

An invalid `sensor`/`port`/`lanes` combination is caught at evaluation time — the flake checks that the corresponding overlay source file exists in the selected L4T branch.

## Examples

### Orin Nano / Orin NX — two sensors

```nix
sensors = [
  { sensor = "imx678"; port = "cam0"; lanes = "2lane"; fpa = "a_p22"; }
  { sensor = "imx565"; port = "cam1"; lanes = "4lane"; fpa = "a_p22"; }
];
```

### AGX Orin — two sensors, one with GMSL

```nix
sensors = [
  { sensor = "imx678"; port = "j5"; lanes = "4lane"; fpa = "4a_agx"; }
  { sensor = "imx662"; port = "j6"; lanes = "2lane"; fpa = "4a_agx"; gmsl = true; }
];
```
