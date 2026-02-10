{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  bun,
}: let
  version = "1.3.7";
in
  stdenv.mkDerivation {
    pname = "skills-cli";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/skills/-/skills-${version}.tgz";
      hash = "sha256-phCJjCeGIefmKYOMguC1dMLPwJ1jvngZZkb/lzv8evs=";
    };

    nativeBuildInputs = [makeWrapper];

    dontBuild = true;

    unpackPhase = ''
      mkdir -p $out/lib/skills
      tar xzf $src --strip-components=1 -C $out/lib/skills
    '';

    installPhase = ''
      mkdir -p $out/bin
      makeWrapper ${bun}/bin/bun $out/bin/skills \
        --add-flags "run" \
        --add-flags "$out/lib/skills/bin/cli.mjs"
    '';

    meta = {
      description = "The open agent skills ecosystem CLI (skills.sh)";
      homepage = "https://skills.sh";
      license = lib.licenses.mit;
      mainProgram = "skills";
    };
  }
