{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skills;

  # State dir uses a placeholder that install.mjs resolves at runtime
  stateFile = "~/.local/state/skills-nix/managed.json";

  # Normalize a source entry: strings become minimal attrsets
  normalizeSource = source:
    if builtins.isString source
    then {source = source;}
    else source;

  normalizedSources = map normalizeSource cfg.sources;

  # Normalize skills filter: plain list → include, attrset passes through
  normalizeSkills = skills:
    if builtins.isList skills
    then {include = skills; exclude = [];}
    else {
      include = skills.include or [];
      exclude = skills.exclude or [];
    };

  # Build the manifest JSON for the custom installer
  manifest = builtins.toJSON {
    inherit (cfg) mode autoUpdate;
    inherit stateFile;
    skillsBin = lib.getExe' cfg.package "skills";
    sources = map (entry: let
      s = normalizeSkills (entry.skills or []);
    in {
      source = entry.source;
      agents =
        if (entry.agents or []) != []
        then entry.agents
        else cfg.defaultAgents;
      skills = {inherit (s) include exclude;};
      fullDepth = entry.fullDepth or true;
    })
    normalizedSources;
  };

  manifestFile = pkgs.writeText "skills-manifest.json" manifest;

  installScript = pkgs.writeShellScriptBin "install-skills" ''
    set -euo pipefail

    # Check network connectivity
    if ! ${lib.getExe pkgs.curl} -sf --max-time 5 https://github.com > /dev/null 2>&1; then
      echo "[skip] No network — run 'install-skills' later"
      exit 0
    fi

    exec ${lib.getExe' cfg.package "skills-install"} ${lib.optionalString cfg.verbose "--verbose"} ${manifestFile} >&2
  '';
in {
  options.programs.skills = {
    enable = lib.mkEnableOption "declarative agent skills management via skills.sh";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix {};
      description = "The skills CLI package to use.";
    };

    mode = lib.mkOption {
      type = lib.types.enum ["symlink" "copy"];
      default = "symlink";
      description = ''
        How skills are installed to agent directories.
        - "symlink": copy to canonical ~/.agents/skills/, symlink from each agent dir (default)
        - "copy": copy directly to each agent dir (no symlinks)
      '';
    };

    defaultAgents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["*"];
      description = ''
        Default agents to install skills to when not specified per-skill.
        Use ["*"] for all agents, or specify e.g. ["opencode" "claude-code" "cursor"].
      '';
    };

    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run `skills update` after installing skills.";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Show detailed per-skill install output. When false, only a summary line is printed.";
    };

    sources = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            description = "Skill source: GitHub shorthand (owner/repo), full URL, or local path.";
            example = "vercel-labs/agent-skills";
          };

          agents = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Agents to install this skill to. Empty list uses `defaultAgents`.
              Use ["*"] for all agents.
            '';
            example = ["opencode" "claude-code"];
          };

          skills = lib.mkOption {
            type = lib.types.either
              (lib.types.listOf lib.types.str)
              (lib.types.submodule {
                options = {
                  include = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [];
                    description = "Skill names to include from the source repo. Empty list means no include filter.";
                    example = ["pr-review" "commit"];
                  };
                  exclude = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [];
                    description = "Skill names to exclude from the source repo.";
                    example = ["deprecated-skill"];
                  };
                };
              });
            default = [];
            description = ''
              Skills filter for this source. Can be:
              - A list of skill names to include (e.g. `["pr-review" "commit"]`)
              - An attrset with `include` (e.g. `{ include = ["pr-review"]; }`)
              - An attrset with `exclude` (e.g. `{ exclude = ["deprecated-skill"]; }`)
              Empty list or `{}` installs all available skills.
            '';
            example = lib.literalExpression ''{ exclude = ["deprecated-skill"]; }'';
          };

          fullDepth = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Recursively search all subdirectories for skills.";
          };
        };
      }));
      default = [];
      description = "List of skill sources to install. Strings are shorthand for {source = \"...\";}.";
      example = lib.literalExpression ''
        [
          "wshobson/agents"
          {
            source = "vercel-labs/agent-skills";
            agents = ["opencode" "claude-code"];
            skills = ["pr-review" "commit"]; # shorthand for include
          }
          {
            source = "anthropics/courses";
            skills = { exclude = ["deprecated-skill"]; };
          }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      cfg.package
      installScript
    ];

    home.activation.installSkills = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ -n "''${DRY_RUN:-}" ]; then
        verboseEcho "Would run install-skills"
      else
        ${installScript}/bin/install-skills
      fi
    '';
  };
}
