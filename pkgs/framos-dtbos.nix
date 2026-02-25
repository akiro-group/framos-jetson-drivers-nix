# Override jetpack-nixos's devicetree package to include Framos camera
# device tree overlay .dts files and the extended overlay Makefile.
#
# The Framos overlay Makefile is a superset of upstream — it includes all
# upstream overlay targets plus the fr_* targets. This means we build
# everything in one pass and replace the base devicetree entirely.
{ runCommand
, devicetree
, framosSrc
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

    # Replace overlay Makefile with Framos version (superset of upstream)
    cp ${framosSrc}/source/hardware/nvidia/t23x/nv-public/overlay/Makefile \
       "$out/hardware/nvidia/t23x/nv-public/overlay/Makefile"
  '';
})
