{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  bun,
  git,
}: let
  version = "1.3.8";
in
  stdenv.mkDerivation {
    pname = "skills-cli";
    inherit version;

    src = fetchurl {
      url = "https://registry.npmjs.org/skills/-/skills-${version}.tgz";
      hash = "sha256-eKGvL6mxQUn81vvCQLlETwHtJ0U762w5p+jQkC+VhSA=";
    };

    nativeBuildInputs = [makeWrapper];

    dontBuild = true;

    unpackPhase = ''
      mkdir -p $out/lib/skills
      tar xzf $src --strip-components=1 -C $out/lib/skills
    '';

    installPhase = ''
      mkdir -p $out/bin $out/lib/skills-nix

      # CLI wrapper
      makeWrapper ${bun}/bin/bun $out/bin/skills \
        --prefix PATH : ${lib.makeBinPath [git]} \
        --add-flags "run" \
        --add-flags "$out/lib/skills/bin/cli.mjs"

      # Custom installer (bypasses CLI, supports mode option)
      cp ${./lib/install.mjs} $out/lib/skills-nix/install.mjs
      makeWrapper ${bun}/bin/bun $out/bin/skills-install \
        --prefix PATH : ${lib.makeBinPath [git]} \
        --add-flags "run" \
        --add-flags "$out/lib/skills-nix/install.mjs"
    '';

    meta = {
      description = "The open agent skills ecosystem CLI (skills.sh)";
      homepage = "https://skills.sh";
      license = lib.licenses.mit;
      mainProgram = "skills";
    };
  }
