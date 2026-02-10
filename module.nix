{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skills;

  stateDir = "\${XDG_STATE_HOME:-$HOME/.local/state}/skills-nix";
  stateFile = "${stateDir}/managed.json";

  # Normalize a skill entry: strings become minimal attrsets
  normalizeSkill = skill:
    if builtins.isString skill
    then {source = skill;}
    else skill;

  normalizedSkills = map normalizeSkill cfg.skills;

  # Build the manifest JSON for the custom installer
  manifest = builtins.toJSON {
    inherit (cfg) mode autoUpdate;
    inherit stateFile;
    skills = map (skill: {
      source = skill.source;
      agents =
        if (skill.agents or []) != []
        then skill.agents
        else cfg.defaultAgents;
      skill = skill.skill or [];
      global = skill.global or cfg.global;
      fullDepth = skill.fullDepth or false;
    })
    normalizedSkills;
  };

  manifestFile = pkgs.writeText "skills-manifest.json" manifest;

  installScript = pkgs.writeShellScriptBin "install-skills" ''
    set -euo pipefail

    # Check network connectivity
    if ! ${lib.getExe pkgs.curl} -sf --max-time 5 https://github.com > /dev/null 2>&1; then
      echo "[skip] No network — run 'install-skills' later"
      exit 0
    fi

    exec ${lib.getExe' cfg.package "skills-install"} ${manifestFile}
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

    global = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install skills globally (user-level) by default.";
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

    skills = lib.mkOption {
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

          skill = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Specific skill names to install from the source repo.
              Empty list installs all available skills. Use ["*"] for all skills explicitly.
            '';
            example = ["pr-review" "commit"];
          };

          global = lib.mkOption {
            type = lib.types.bool;
            default = cfg.global;
            description = "Install this skill globally (user-level).";
          };

          fullDepth = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Search all subdirectories even when a root SKILL.md exists.";
          };
        };
      }));
      default = [];
      description = "List of skills to install. Strings are shorthand for {source = \"...\";}.";
      example = lib.literalExpression ''
        [
          "wshobson/agents"
          {
            source = "vercel-labs/agent-skills";
            agents = ["opencode" "claude-code"];
            skill = ["pr-review" "commit"];
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
