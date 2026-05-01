{
  description = "FRAMOS Jetson camera sensor drivers for NixOS";

  inputs = {
    framos-src = {
      url = "github:framosimaging/framos-jetson-drivers/l4t-r36.4.4";
      flake = false;
    };
  };

  outputs = { self, framos-src }:
    let
      framosPatches = map (p: "${self}/patches/nvidia-oot/${p}") [
        "0001-framos-camera-headers.patch"
        "0002-framos-camera-platform.patch"
        "0003-framos-i2c-makefile.patch"
      ];

      framosDevicetreePatches = map (p: "${self}/patches/devicetree/${p}") [
        "0001-framos-overlay-makefile-targets.patch"
      ];
    in
    {
      nixosModules.default = import ./modules/default.nix {
        inherit framos-src framosPatches framosDevicetreePatches;
      };
      nixosModules.framos-jetson-drivers = self.nixosModules.default;
    };
}
