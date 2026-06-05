{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.skills;

  # Marker file: stores the Nix store path of the commands file we last applied.
  # This tracks "which generation did we reconcile", NOT skill state — the skills
  # CLI owns skill tracking via its own global lock file.
  stateDir = "\${XDG_STATE_HOME:-$HOME/.local/state}/skills-nix";
  marker = "${stateDir}/applied";

  # Normalize a source entry: bare strings become minimal attrsets.
  normalizeSource = source:
    if builtins.isString source
    then {source = source;}
    else source;

  normalizedSources = map normalizeSource cfg.sources;

  # Normalize a skills filter into a plain include list.
  #   ["a" "b"]            → ["a" "b"]
  #   { include = [...]; } → that list
  includeOf = skills:
    if builtins.isList skills
    then skills
    else skills.include or [];

  # Render one `skills add` invocation for a source entry.
  addCommand = entry: let
    agents =
      if (entry.agents or []) != []
      then entry.agents
      else cfg.defaultAgents;
    include = includeOf (entry.skills or []);

    agentFlag = "-a " + lib.concatMapStringsSep " " lib.escapeShellArg agents;
    skillFlag =
      lib.optionalString
      (include != [] && include != ["*"])
      ("-s " + lib.concatMapStringsSep " " lib.escapeShellArg include);
    copyFlag = lib.optionalString (cfg.mode == "copy") "--copy";
  in
    lib.concatStringsSep " " (lib.filter (s: s != "") [
      "skills add"
      (lib.escapeShellArg entry.source)
      "-g -y"
      agentFlag
      skillFlag
      copyFlag
    ]);

  # The generated command list. Its /nix/store path is the change-gate identity:
  # if the config is unchanged, the path is identical and we skip the reconcile.
  commandsFile = pkgs.writeText "skills-commands.sh" (
    lib.concatMapStringsSep "\n" addCommand normalizedSources + "\n"
  );

  installScript = pkgs.writeShellApplication {
    name = "install-skills";
    runtimeInputs = [cfg.package pkgs.curl pkgs.coreutils];
    text = ''
      force=0
      [ "''${1:-}" = "--force" ] && force=1

      ${lib.optionalString (! cfg.telemetry) "export DO_NOT_TRACK=1"}

      marker="${marker}"

      # Skip when the desired state is unchanged (zero network).
      if [ "$force" -eq 0 ] && [ -f "$marker" ] && \
         [ "$(cat "$marker")" = "${commandsFile}" ]; then
        ${
        if cfg.verbose
        then ''echo "[skip] skills config unchanged"''
        else ":"
      }
        ${lib.optionalString cfg.autoUpdate "skills update -g -y || true"}
        exit 0
      fi

      # Network check — defer gracefully when offline.
      if ! curl -sf --max-time 5 https://github.com > /dev/null 2>&1; then
        echo "[skip] No network — run 'install-skills' later"
        exit 0
      fi

      # Declarative ownership: wipe all global skills, then rebuild from config.
      skills remove --all -g -y || true

      failed=0
      while IFS= read -r cmd; do
        [ -z "$cmd" ] && continue
        ${lib.optionalString cfg.verbose ''echo "+ $cmd"''}
        eval "$cmd" || { echo "  ⚠️  failed: $cmd" >&2; failed=1; }
      done < ${commandsFile}

      ${lib.optionalString cfg.autoUpdate "skills update -g -y || true"}

      # Only record success — a failed source retries on the next activation.
      if [ "$failed" -eq 0 ]; then
        mkdir -p "$(dirname "$marker")"
        printf '%s' "${commandsFile}" > "$marker"
      else
        echo "[warn] some sources failed; will retry next activation" >&2
      fi
    '';
  };
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
        - "symlink": single canonical copy under ~/.agents/skills, symlinked
          into each agent dir (default, passes nothing to the CLI).
        - "copy": copy directly into each agent dir (passes `--copy`).
      '';
    };

    defaultAgents = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["*"];
      description = ''
        Default agents to install skills to when a source does not set its own.
        Use ["*"] for all detected agents, or specific names recognised by the
        skills CLI (e.g. ["opencode" "claude-code" "cursor"]).
      '';
    };

    autoUpdate = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Run `skills update -g -y` after reconciling, to pull upstream skill changes.";
    };

    verbose = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Echo each `skills` command as it runs.";
    };

    telemetry = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Allow the skills CLI to send its privacy-preserving telemetry during
        activation. When false (default), `DO_NOT_TRACK=1` is exported so
        declarative runs stay silent.
      '';
    };

    sources = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str (lib.types.submodule {
        options = {
          source = lib.mkOption {
            type = lib.types.str;
            description = ''
              Skill source, passed verbatim to `skills add`. Supports GitHub
              shorthand (owner/repo), refs and subpaths
              (owner/repo/tree/<ref>/<path>), full GitHub/GitLab URLs,
              HuggingFace, any git URL, direct URLs, and local paths.
            '';
            example = "vercel-labs/agent-skills";
          };

          agents = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = ''
              Agents to install this source's skills to. Empty list uses
              `defaultAgents`. Use ["*"] for all detected agents.
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
                    description = "Skill names to install from the source. Empty installs all.";
                    example = ["pr-review" "commit"];
                  };
                };
              });
            default = [];
            description = ''
              Which skills to install from this source (maps to `skills add -s`).
              Either a list of names (`["pr-review" "commit"]`) or
              `{ include = [...]; }`. Empty list or `["*"]` installs all
              available skills.
            '';
            example = lib.literalExpression ''["pr-review" "commit"]'';
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
            skills = ["pr-review" "commit"];
          }
          {
            source = "anthropics/courses/tree/main/skills";
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
        ${lib.getExe installScript}
      fi
    '';
  };
}
