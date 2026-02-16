# ⚙️ Configuration Reference

All options live under `programs.skills` in your Home Manager configuration.

## `programs.skills.enable`

- **Type:** `bool`
- **Default:** `false`

✅ Enable declarative agent skills management.

```nix
programs.skills.enable = true;
```

## `programs.skills.package`

- **Type:** `package`
- **Default:** built-in `skills-cli` derivation

📦 The skills CLI package to use. Override this if you want to pin a different version or use a custom build. See [vercel-labs/skills](https://github.com/vercel-labs/skills) for the upstream CLI.

```nix
programs.skills.package = pkgs.callPackage ./my-custom-skills.nix {};
```

## `programs.skills.mode`

- **Type:** `enum ["symlink" "copy"]`
- **Default:** `"symlink"`

🔗 How skills are installed to agent directories.

| Mode | Behavior |
|---|---|
| 🔗 `"symlink"` | Copies to `~/.agents/skills/`, then creates symlinks from each agent directory. Space-efficient, single source of truth. |
| 📋 `"copy"` | Copies directly to each agent directory. More isolated, no symlinks. |

```nix
programs.skills.mode = "copy";
```

## `programs.skills.defaultAgents`

- **Type:** `listOf str`
- **Default:** `["*"]`

🤖 Default agents to install skills to when not specified per-source. Use `["*"]` for all agents, or list specific ones.

```nix
programs.skills.defaultAgents = ["opencode" "claude-code" "cursor"];
```

### 📝 Valid agent names

`opencode`, `claude-code`, `cursor`, `codex`, `gemini-cli`, `github-copilot`, `amp`, `antigravity`, `cline`, `goose`, `roo`, `windsurf`, `trae`, `kilo`, `kiro-cli`, `droid`

## `programs.skills.autoUpdate`

- **Type:** `bool`
- **Default:** `true`

🔄 Run `skills update` after installing skills. This fetches any upstream changes via the [skills CLI](https://github.com/vercel-labs/skills).

```nix
programs.skills.autoUpdate = false;
```

## `programs.skills.verbose`

- **Type:** `bool`
- **Default:** `false`

🔊 Show detailed per-skill install output. When `false` (the default), only a summary line like `✅ 12 installed, 3 skipped (cached)` is printed. Set to `true` to see every skill install, skip, and removal as it happens.

```nix
programs.skills.verbose = true;
```

## `programs.skills.sources`

- **Type:** `listOf (either str submodule)`
- **Default:** `[]`

📚 List of skill sources to install. Each entry can be:

- A **string** — shorthand for `{ source = "..."; }` with all defaults
- An **attribute set** — full control over source, agents, skill filtering, etc.

### 🔤 String form (simple)

```nix
programs.skills.sources = [
  "wshobson/agents"
  "vercel-labs/agent-skills"
];
```

### 🧩 Attribute set form (advanced)

Each source submodule supports these options:

#### `source`

- **Type:** `str`
- **Required** ⚠️

Skill source identifier. Accepts:

| Format | Example |
|---|---|
| 🐙 GitHub shorthand | `"owner/repo"` |
| 🌐 Full URL | `"https://github.com/owner/repo.git"` |
| 🔑 SSH URL | `"git@github.com:owner/repo.git"` |
| 📁 Local path | `"/home/user/my-skills"` or `"./relative-path"` |

#### `agents`

- **Type:** `listOf str`
- **Default:** `[]` (inherits from `defaultAgents`)

🤖 Agents to install this source's skills to. Empty list falls back to `defaultAgents`.

#### `skills`

- **Type:** `listOf str`
- **Default:** `[]`

🎯 Specific skill names to install from the source. Empty list installs all discovered skills. Use `["*"]` to explicitly install all.

#### `fullDepth`

- **Type:** `bool`
- **Default:** `true`

🔍 Recursively search all subdirectories for skills (directories containing `SKILL.md`). Set to `false` for top-level only.

### 💡 Full example

```nix
programs.skills.sources = [
  # Simple: install all skills from this repo to all agents
  "wshobson/agents"

  # Advanced: selective install
  {
    source = "vercel-labs/agent-skills";
    agents = ["opencode" "claude-code"];
    skills = ["pr-review" "commit"];
  }

  # Local path
  {
    source = "~/my-custom-skills";
    agents = ["opencode"];
  }
];
```
