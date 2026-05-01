# Override jetpack-nixos's devicetree package to include Framos camera
# device tree overlay .dts files and the extended overlay Makefile.
{
  runCommand,
  devicetree,
  framosSrc,
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

    # Append Framos fr_* targets to the upstream Makefile
    grep 'fr_' ${framosSrc}/source/hardware/nvidia/t23x/nv-public/overlay/Makefile \
      >> "$out/hardware/nvidia/t23x/nv-public/overlay/Makefile"
  '';
})
