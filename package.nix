{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  bun,
  git,
}: let
  version = "1.5.10";
in
  stdenv.mkDerivation {
    pname = "skills-cli";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/skills/-/skills-${version}.tgz";
      hash = "sha256-FjDG4GJRKrmxEL15Mkp3j+RhAUbq2kl3Yg53BGuNO/M=";
    };

    nativeBuildInputs = [makeWrapper];

    dontBuild = true;

    unpackPhase = ''
      mkdir -p $out/lib/skills
      tar xzf $src --strip-components=1 -C $out/lib/skills
    '';

    installPhase = ''
      mkdir -p $out/bin

      # CLI wrapper
      makeWrapper ${bun}/bin/bun $out/bin/skills \
        --prefix PATH : ${lib.makeBinPath [git]} \
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
