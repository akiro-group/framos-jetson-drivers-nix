{
  description = "FRAMOS Jetson camera sensor drivers for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    framos-src-r36_3   = { url = "github:framosimaging/framos-jetson-drivers/l4t-r36.3";   flake = false; };
    framos-src-r36_4   = { url = "github:framosimaging/framos-jetson-drivers/l4t-r36.4";   flake = false; };
    framos-src-r36_4_3 = { url = "github:framosimaging/framos-jetson-drivers/l4t-r36.4.3"; flake = false; };
    framos-src-r36_4_4 = { url = "github:framosimaging/framos-jetson-drivers/l4t-r36.4.4"; flake = false; };
    framos-src-r38_4   = { url = "github:framosimaging/framos-jetson-drivers/l4t-r38.4";   flake = false; };
  };

  outputs = { self, nixpkgs
            , framos-src-r36_3, framos-src-r36_4, framos-src-r36_4_3
            , framos-src-r36_4_4, framos-src-r38_4 }:
    let
      srcForVersion = {
        "36.3"   = framos-src-r36_3;
        "36.4"   = framos-src-r36_4;
        "36.4.3" = framos-src-r36_4_3;
        "36.4.4" = framos-src-r36_4_4;
        "38.4"   = framos-src-r38_4;
      };

      nixosModule = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.hardware.framos-jetson-drivers;

          agxPorts  = [ "j5" "j6" "j7" "j8" ];
          nxPorts   = [ "cam0" "cam1" ];

          agxFpas = [ "4a_agx" "4a_txa" ];
          nxFpas  = [ "a_p22" ];

          validSensors = [
            "imx283" "imx296" "imx304" "imx335" "imx412" "imx464"
            "imx530" "imx565" "imx568" "imx577" "imx585" "imx636"
            "imx662" "imx675" "imx676" "imx678" "imx715" "imx838"
            "imx900"
          ];

          isAgxPort = port: builtins.elem port agxPorts;

          boardPrefix = port:
            if isAgxPort port
            then "tegra234-p3737-camera-fr_"
            else "tegra234-p3767-camera-p3768-fr_";

          overlayDir = "${framosSrc}/source/hardware/nvidia/t23x/nv-public/overlay";

          # Values are passed pre-formatted and appear verbatim in filenames.
          sensorOverlays = { sensor, port, lanes, gmsl, fpa }:
            let prefix = boardPrefix port; in
            [ "${prefix}fpa_${fpa}-overlay.dtbo"
              "${prefix}${sensor}-${port}-${lanes}-overlay.dtbo"
            ] ++ optional gmsl "${prefix}${port}-gmsl-overlay.dtbo";

          # Check that a sensor+port+lanes combo has a corresponding DTS in the source.
          overlayExists = { sensor, port, lanes, ... }:
            let name = "${boardPrefix port}${sensor}-${port}-${lanes}-overlay.dts"; in
            builtins.pathExists "${overlayDir}/${name}";

          allOverlays = unique (concatMap sensorOverlays cfg.sensors);

          framosSrc = srcForVersion.${cfg.l4tVersion};

          framosDrivers = pkgs.stdenv.mkDerivation {
            pname   = "framos-jetson-drivers";
            version = cfg.l4tVersion;

            src = framosSrc;

            patches = [
              "${self}/patches/0001-nixos-fix-split-kernel-tree-build.patch"
              "${self}/patches/0002-rtl8822ce-fix-gcc14-Waddress-errors.patch"
              "${self}/patches/0003-nixos-remove-sudo-depmod-from-modules-install.patch"
            ];

            nativeBuildInputs = with pkgs; [ flex bison openssl dtc ]
              ++ config.boot.kernelPackages.kernel.moduleBuildDependencies;

            KERNEL_SOURCE  = "${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/source";
            KERNEL_HEADERS = "${config.boot.kernelPackages.kernel.dev}/lib/modules/${config.boot.kernelPackages.kernel.modDirVersion}/build";

            buildPhase = ''
              make -C source dtbs \
                TEGRA_TOP=$PWD/source \
                srctree="$KERNEL_SOURCE" \
                objtree="$KERNEL_HEADERS" \
                oottree=$PWD/source/kernel-devicetree \
                HOSTCC=gcc

              make -C source modules \
                KERNEL_HEADERS="$KERNEL_HEADERS" \
                KERNEL_OUTPUT="$KERNEL_HEADERS" \
                NPROC=$(nproc)
            '';

            installPhase = ''
              install -d $out/boot/framos/dtbo
              cp source/kernel-devicetree/generic-dts/dtbs/*fr_*.dtbo \
                $out/boot/framos/dtbo/

              make -C source modules_install \
                INSTALL_MOD_PATH=$out \
                KERNEL_HEADERS="$KERNEL_HEADERS" \
                KERNEL_OUTPUT="$KERNEL_HEADERS"

              install -d $out/bin
              install -m 0755 tools/jetson-config-camera-cli.py $out/bin/
              install -m 0755 tools/jetson-config-camera.py     $out/bin/
              install -m 0755 tools/crosslink_configurator      $out/bin/

              install -d $out/opt/framos
              cp -r firmware $out/opt/framos/
            '';

            meta = with lib; {
              description = "FRAMOS Jetson camera sensor drivers (kernel modules + DT overlays)";
              license     = licenses.gpl2Only;
              platforms   = [ "aarch64-linux" ];
            };
          };

        in
        {
          options.hardware.framos-jetson-drivers = {

            enable = mkEnableOption "FRAMOS Jetson camera sensor drivers";

            l4tVersion = mkOption {
              type        = types.enum (attrNames srcForVersion);
              default     = "36.4.4";
              description = "L4T version; selects the matching upstream branch.";
            };

            sensors = mkOption {
              default     = [];
              description = "List of camera sensor configurations.";
              example = literalExpression ''
                [
                  { sensor = "imx678"; port = "cam0"; lanes = "2lane"; fpa = "a_p22"; }
                ]
              '';
              type = types.listOf (types.submodule {
                options = {
                  sensor = mkOption {
                    type        = types.enum validSensors;
                    description = "Sensor model, e.g. \"imx678\".";
                  };
                  port = mkOption {
                    type        = types.enum (agxPorts ++ nxPorts);
                    description = "Connector port: j5–j8 (AGX Orin) or cam0/cam1 (Orin Nano/NX).";
                  };
                  lanes = mkOption {
                    type        = types.enum [ "1lane" "2lane" "4lane" ];
                    description = "Number of CSI lanes.";
                  };
                  fpa = mkOption {
                    type        = types.enum (agxFpas ++ nxFpas);
                    description = "FPA adapter: 4a_agx / 4a_txa (AGX Orin) or a_p22 (Orin Nano/NX).";
                  };
                  gmsl = mkOption {
                    type    = types.bool;
                    default = false;
                    description = "Apply the GMSL overlay for this port.";
                  };
                };
              });
            };
          };

          config = mkIf cfg.enable {

            assertions = concatMap (s: [
              {
                assertion = isAgxPort s.port -> builtins.elem s.fpa agxFpas;
                message   = "framos: AGX port \"${s.port}\" requires fpa in {${concatStringsSep ", " agxFpas}}, got \"${s.fpa}\".";
              }
              {
                assertion = !(isAgxPort s.port) -> builtins.elem s.fpa nxFpas;
                message   = "framos: NX/Nano port \"${s.port}\" requires fpa in {${concatStringsSep ", " nxFpas}}, got \"${s.fpa}\".";
              }
              {
                assertion = overlayExists s;
                message   = "framos: no overlay exists for sensor=\"${s.sensor}\" port=\"${s.port}\" lanes=\"${s.lanes}\" in l4t-${cfg.l4tVersion}.";
              }
            ]) cfg.sensors;

            boot.extraModulePackages = [ framosDrivers ];

            system.activationScripts.framosJetsonDtbo = {
              text = ''
                echo "framos: installing DTBO overlays..."
                install -d /boot/framos/dtbo
                cp -f ${framosDrivers}/boot/framos/dtbo/*.dtbo /boot/framos/dtbo/
              '';
              deps = [];
            };

            system.activationScripts.framosJetsonExtlinux = {
              text = mkIf (cfg.sensors != []) ''
                echo "framos: configuring extlinux overlays..."
                EXTLINUX=/boot/extlinux/extlinux.conf
                # Ensure FDT entry exists
                if ! grep -q "^[[:space:]]*FDT" "$EXTLINUX"; then
                  BASE_DTB=$(basename /boot/dtb/*)
                  sed -i "/MENU LABEL primary kernel/{N;N;s|$|\n      FDT /boot/dtb/$BASE_DTB|}" "$EXTLINUX"
                fi
                # Write (or replace) OVERLAYS line
                OVERLAYS="${concatMapStrings (o: "/boot/framos/dtbo/${o} ") allOverlays}"
                OVERLAYS="''${OVERLAYS% }"  # strip trailing space
                if grep -q "^[[:space:]]*OVERLAYS" "$EXTLINUX"; then
                  sed -i "s|^[[:space:]]*OVERLAYS.*|      OVERLAYS $OVERLAYS|" "$EXTLINUX"
                else
                  sed -i "/^[[:space:]]*FDT/a\\      OVERLAYS $OVERLAYS" "$EXTLINUX"
                fi
              '';
              deps = [ "framosJetsonDtbo" ];
            };

            system.activationScripts.framosJetsonFirmware = {
              text = ''
                echo "framos: installing CrossLink firmware..."
                install -d /opt/framos
                cp -rf ${framosDrivers}/opt/framos/firmware /opt/framos/
              '';
              deps = [];
            };
          };
        };

    in
    {
      nixosModules.default = nixosModule;
      nixosModules.framos-jetson-drivers = nixosModule;
    };
}
