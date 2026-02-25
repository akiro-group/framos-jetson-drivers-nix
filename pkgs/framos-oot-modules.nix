# Override jetpack-nixos's nvidia-oot-modules to include Framos camera
# driver patches and new sensor driver source files.
#
# This works by:
# 1. Taking the already-patched nvidia-oot source from jetpack-nixos
# 2. Applying Framos modification patches (camera infrastructure changes)
# 3. Copying in new Framos-only source files (sensor drivers, headers)
{ lib
, runCommand
, nvidia-oot-modules
, framosSrc
, framosPatches
}:

let
  framosNewFiles = runCommand "framos-new-oot-files" { } ''
    mkdir -p $out/drivers/i2c
    mkdir -p $out/drivers/media/i2c
    mkdir -p $out/include/i2c
    mkdir -p $out/include/media

    # Generic I2C driver
    cp ${framosSrc}/source/nvidia-oot/drivers/i2c/fr_i2c_generic.c \
       $out/drivers/i2c/

    # Sensor drivers, bridge drivers, common utilities (.c and .h)
    for f in ${framosSrc}/source/nvidia-oot/drivers/media/i2c/fr_*; do
      [ -f "$f" ] && cp "$f" $out/drivers/media/i2c/
    done

    # I2C header
    cp ${framosSrc}/source/nvidia-oot/include/i2c/fr_i2c_generic.h \
       $out/include/i2c/

    # Public media headers
    for f in ${framosSrc}/source/nvidia-oot/include/media/fr_*.h; do
      cp "$f" $out/include/media/
    done
  '';
in
nvidia-oot-modules.overrideAttrs (old: {
  pname = "framos-l4t-oot-modules";

  # Rebuild the source tree with Framos changes layered on top.
  # old.src is the assembled l4t-oot-sources from jetpack-nixos
  # (with jetpack-nixos's own nvidia-oot patches already applied).
  src = runCommand "framos-l4t-oot-sources" { } ''
    cp --no-preserve=all -r ${old.src}/. $out
    chmod -R u+w $out/nvidia-oot

    # Apply Framos camera infrastructure patches
    ${lib.concatMapStringsSep "\n"
      (p: "patch -p1 -d $out/nvidia-oot < ${p}")
      framosPatches}

    # Copy new Framos-only source files
    cp ${framosNewFiles}/drivers/i2c/fr_i2c_generic.c \
       $out/nvidia-oot/drivers/i2c/

    cp ${framosNewFiles}/drivers/media/i2c/fr_*.c \
       ${framosNewFiles}/drivers/media/i2c/fr_*_mode_tbls.h \
       $out/nvidia-oot/drivers/media/i2c/

    mkdir -p $out/nvidia-oot/include/i2c
    cp ${framosNewFiles}/include/i2c/fr_i2c_generic.h \
       $out/nvidia-oot/include/i2c/

    cp ${framosNewFiles}/include/media/fr_*.h \
       $out/nvidia-oot/include/media/
  '';
})
