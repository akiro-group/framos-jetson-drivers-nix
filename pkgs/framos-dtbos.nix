# Override jetpack-nixos's devicetree package to include Framos camera
# device tree overlay .dts files and the fr_* dtbo-y Makefile targets.
{
  lib,
  runCommand,
  devicetree,
  framosSrc,
  framosDevicetreePatches,
}:

devicetree.overrideAttrs (old: {
  pname = "framos-l4t-devicetree";

  src = runCommand "framos-dtbo-sources" { } ''
    cp --no-preserve=all -r ${old.src}/. $out
    chmod -R u+w $out/hardware/nvidia/t23x/nv-public/overlay

    # Add Framos overlay .dts files
    for f in ${framosSrc}/source/hardware/nvidia/t23x/nv-public/overlay/tegra234-*-fr_*.dts; do
      cp "$f" "$out/hardware/nvidia/t23x/nv-public/overlay/"
    done

    # Patch the upstream Makefile to add Framos dtbo-y targets
    ${lib.concatMapStringsSep "\n"
      (p: "patch -p1 -d $out < ${p}")
      framosDevicetreePatches}
  '';
})
