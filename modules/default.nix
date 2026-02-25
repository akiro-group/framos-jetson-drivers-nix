{ framos-src, framosPatches }:

{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.hardware.framos-jetson-drivers;

  framosSrc = framos-src;

  agxPorts = [ "j5" "j6" "j7" "j8" ];
  nxPorts  = [ "cam0" "cam1" ];

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

  sensorOverlays = { sensor, port, lanes, gmsl, fpa }:
    let prefix = boardPrefix port; in
    [ "${prefix}fpa_${fpa}-overlay.dtbo"
      "${prefix}${sensor}-${port}-${lanes}-overlay.dtbo"
    ] ++ optional gmsl "${prefix}${port}-gmsl-overlay.dtbo";

  overlayExists = { sensor, port, lanes, ... }:
    let name = "${boardPrefix port}${sensor}-${port}-${lanes}-overlay.dts"; in
    builtins.pathExists "${overlayDir}/${name}";

  allOverlays = unique (concatMap sensorOverlays cfg.sensors);

  framosTools = pkgs.runCommand "framos-tools" { } ''
    install -d $out/bin
    install -m 0755 ${framosSrc}/tools/jetson-config-camera-cli.py $out/bin/
    install -m 0755 ${framosSrc}/tools/jetson-config-camera.py     $out/bin/
    install -m 0755 ${framosSrc}/tools/crosslink_configurator      $out/bin/
  '';

in
{
  options.hardware.framos-jetson-drivers = {

    enable = mkEnableOption "FRAMOS Jetson camera sensor drivers";

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
        message   = "framos: no overlay exists for sensor=\"${s.sensor}\" port=\"${s.port}\" lanes=\"${s.lanes}\".";
      }
    ]) cfg.sensors;

    # Extend jetpack-nixos's kernelPackagesOverlay to:
    # 1. Patch nvidia-oot-modules with Framos camera driver changes
    # 2. Override devicetree to include Framos DTBO overlays
    nixpkgs.overlays = mkAfter [
      (_final: prev: {
        nvidia-jetpack = prev.nvidia-jetpack // {
          kernelPackagesOverlay = kFinal: kPrev:
            let
              base = prev.nvidia-jetpack.kernelPackagesOverlay kFinal kPrev;
            in
            base // {
              nvidia-oot-modules = kFinal.callPackage (import ../pkgs/framos-oot-modules.nix) {
                inherit framosSrc framosPatches;
                nvidia-oot-modules = base.nvidia-oot-modules;
              };
              devicetree = kFinal.callPackage (import ../pkgs/framos-dtbos.nix) {
                inherit framosSrc;
                devicetree = base.devicetree;
              };
            };
        };
      })
    ];

    # Select which Framos DTBOs to apply at flash time
    hardware.nvidia-jetpack.flashScriptOverrides.additionalDtbOverlays =
      map (o: "${config.boot.kernelPackages.devicetree}/${o}") allOverlays;

    environment.systemPackages = [ framosTools ];

    system.activationScripts.framosJetsonFirmware = {
      text = ''
        echo "framos: installing CrossLink firmware..."
        install -d /opt/framos
        cp -rf ${framosSrc}/firmware /opt/framos/
      '';
      deps = [];
    };
  };
}
