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

  # Resolve effective agents for a skill entry
  effectiveAgents = skill:
    if (skill.agents or []) != []
    then skill.agents
    else cfg.defaultAgents;

  # Build the `skills add` command for a single skill entry, capturing
  # which skill names were installed by diffing the skills directory.
  mkAddCmd = skill: let
    source = skill.source;
    agents = effectiveAgents skill;
    skills' = skill.skill or [];
    global = skill.global or cfg.global;
    fullDepth = skill.fullDepth or false;

    agentArgs =
      if agents == ["*"]
      then "--agent '*'"
      else lib.concatMapStringsSep " " (a: "--agent ${lib.escapeShellArg a}") agents;

    skillArgs =
      if skills' == ["*"]
      then "--skill '*'"
      else if skills' != []
      then lib.concatMapStringsSep " " (s: "--skill ${lib.escapeShellArg s}") skills'
      else "";

    globalArg = lib.optionalString global "--global";
    fullDepthArg = lib.optionalString fullDepth "--full-depth";
  in ''
    # Snapshot before add
    _before=$(ls "$SKILLS_DIR" 2>/dev/null | sort)

    echo "  -> ${source}"
    ${lib.getExe cfg.package} add ${lib.escapeShellArg source} \
      ${globalArg} ${agentArgs} ${skillArgs} ${fullDepthArg} \
      --yes 2>/dev/null || echo "     [warn] failed: ${source}"

    # Snapshot after add — record newly installed skill names for this source
    _after=$(ls "$SKILLS_DIR" 2>/dev/null | sort)
    _new=$(comm -13 <(echo "$_before") <(echo "$_after"))
    _existing=""
    if [ -n "${lib.escapeShellArg (builtins.toJSON (skills'))}" ] && [ ${lib.escapeShellArg (builtins.toJSON (skills'))} != "[]" ]; then
      _existing=${lib.escapeShellArg (builtins.toJSON (skills'))}
    fi

    # Merge: use explicitly listed skill names if provided, otherwise use discovered ones
    if [ -n "$_existing" ] && [ "$_existing" != "[]" ]; then
      _names="$_existing"
    elif [ -n "$_new" ]; then
      _names=$(echo "$_new" | ${pkgs.jq}/bin/jq -R -s 'split("\n") | map(select(. != ""))')
    else
      _names="[]"
    fi

    # Update new state: merge into the JSON object
    _new_state=$(echo "$_new_state" | ${pkgs.jq}/bin/jq \
      --arg source ${lib.escapeShellArg source} \
      --argjson names "$_names" \
      --argjson agents ${lib.escapeShellArg (builtins.toJSON agents)} \
      '. + {($source): {skills: $names, agents: $agents}}')
  '';

  # Build the desired sources set as a JSON object (for removal diffing)
  desiredSourcesJSON = builtins.toJSON (map (s: s.source) normalizedSkills);

  installScript = pkgs.writeShellScriptBin "install-skills" ''
    set -euo pipefail

    SKILLS_DIR="$HOME/.agents/skills"
    mkdir -p "$SKILLS_DIR" "${stateDir}"

    echo "Reconciling agent skills..."
    echo ""

    # Check network connectivity
    if ! ${lib.getExe pkgs.curl} -sf --max-time 5 https://github.com > /dev/null 2>&1; then
      echo "[skip] No network — run 'install-skills' later"
      exit 0
    fi

    # ── Phase 1: Remove stale managed skills ──────────────────────────
    _old_state="{}"
    if [ -f "${stateFile}" ]; then
      _old_state=$(cat "${stateFile}")
    fi

    _desired_sources=${lib.escapeShellArg desiredSourcesJSON}

    # Find sources in old state but NOT in current config
    _stale_sources=$(echo "$_old_state" | ${pkgs.jq}/bin/jq -r \
      --argjson desired "$_desired_sources" \
      'keys | map(select(. as $s | $desired | index($s) | not)) | .[]')

    if [ -n "$_stale_sources" ]; then
      echo "Removing skills from dropped sources..."
      while IFS= read -r _source; do
        _skill_names=$(echo "$_old_state" | ${pkgs.jq}/bin/jq -r \
          --arg s "$_source" '.[$s].skills // [] | .[]')

        while IFS= read -r _name; do
          [ -z "$_name" ] && continue
          echo "  <- removing $_name (from $_source)"
          ${lib.getExe cfg.package} remove "$_name" \
            --global --yes 2>/dev/null \
            || echo "     [warn] failed to remove: $_name"
        done <<< "$_skill_names"
      done <<< "$_stale_sources"
      echo ""
    fi

    # ── Phase 2: Install/ensure declared skills ───────────────────────
    echo "Installing declared skills..."
    _new_state="{}"

    ${lib.concatMapStringsSep "\n" mkAddCmd normalizedSkills}

    # ── Phase 3: Write new state ──────────────────────────────────────
    echo "$_new_state" | ${pkgs.jq}/bin/jq '.' > "${stateFile}"

    ${lib.optionalString cfg.autoUpdate ''
      echo ""
      echo "Updating all skills..."
      ${lib.getExe cfg.package} update 2>/dev/null || echo "[warn] update failed"
    ''}

    echo ""
    echo "Done. State saved to ${stateFile}"
  '';
in {
  options.programs.skills = {
    enable = lib.mkEnableOption "declarative agent skills management via skills.sh";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix {};
      description = "The skills CLI package to use.";
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
            description = ''
              Skill source: GitHub shorthand (owner/repo), full URL, or local path.
            '';
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
              Empty list installs all available skills.
              Use ["*"] for all skills explicitly.
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
        # Run in background to avoid blocking the switch
        ${installScript}/bin/install-skills &
        disown
      fi
    '';
  };
}
