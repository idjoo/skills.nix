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

📦 The skills CLI package to use. Override this to pin a different version or use
a custom build. See [vercel-labs/skills](https://github.com/vercel-labs/skills)
for the upstream CLI.

```nix
programs.skills.package = pkgs.callPackage ./my-custom-skills.nix {};
```

## `programs.skills.mode`

- **Type:** `enum ["symlink" "copy"]`
- **Default:** `"symlink"`

🔗 How skills are installed to agent directories (maps to the CLI's `--copy`).

| Mode | Behavior |
|---|---|
| 🔗 `"symlink"` | One canonical copy under `~/.agents/skills`, symlinked into each agent directory. Space-efficient. |
| 📋 `"copy"` | An independent copy in each agent directory (passes `--copy`). Fully isolated. |

```nix
programs.skills.mode = "copy";
```

## `programs.skills.defaultAgents`

- **Type:** `listOf str`
- **Default:** `["*"]`

🤖 Default agents to install skills to when a source doesn't set its own. Use
`["*"]` for all detected agents, or list specific names. The CLI supports 70+
agents — see [its docs](https://github.com/vercel-labs/skills) for the full set
(e.g. `opencode`, `claude-code`, `cursor`, `codex`, `gemini-cli`,
`github-copilot`, `cline`, `goose`, `windsurf`, …).

```nix
programs.skills.defaultAgents = ["opencode" "claude-code" "cursor"];
```

## `programs.skills.autoUpdate`

- **Type:** `bool`
- **Default:** `true`

🔄 Run `skills update -g -y` after reconciling, to pull upstream skill changes
(the CLI compares stored GitHub tree SHAs to detect updates).

```nix
programs.skills.autoUpdate = false;
```

## `programs.skills.verbose`

- **Type:** `bool`
- **Default:** `false`

🔊 Echo each `skills` command as it runs. Useful for debugging which sources are
being reconciled.

```nix
programs.skills.verbose = true;
```

## `programs.skills.telemetry`

- **Type:** `bool`
- **Default:** `false`

📊 Whether to allow the skills CLI's privacy-preserving telemetry during
activation. When `false` (default), `DO_NOT_TRACK=1` is exported so declarative
runs stay silent. Set to `true` to opt in.

```nix
programs.skills.telemetry = true;
```

## `programs.skills.sources`

- **Type:** `listOf (either str submodule)`
- **Default:** `[]`

📚 List of skill sources to install. Each entry can be:

- A **string** — shorthand for `{ source = "..."; }` with all defaults
- An **attribute set** — full control over source, agents, and skill selection

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

Skill source, passed verbatim to `skills add`. The CLI accepts a rich set of
formats:

| Format | Example |
|---|---|
| 🐙 GitHub shorthand | `"owner/repo"` |
| 🌿 Ref + subpath | `"owner/repo/tree/main/skills"` |
| 🦊 GitLab | `"https://gitlab.com/owner/repo"` |
| 🤗 HuggingFace | `"https://huggingface.co/owner/repo"` |
| 🌐 Full / git URL | `"https://github.com/owner/repo.git"`, `"git@github.com:owner/repo.git"` |
| 📁 Local path | `"/home/user/my-skills"` or `"./relative-path"` |

#### `agents`

- **Type:** `listOf str`
- **Default:** `[]` (inherits from `defaultAgents`)

🤖 Agents to install this source's skills to. Empty list falls back to
`defaultAgents`. Use `["*"]` for all detected agents.

#### `skills`

- **Type:** `either (listOf str) { include; }`
- **Default:** `[]`

🎯 Which skills to install from the source (maps to `skills add -s`). Two forms:

| Form | Example | Behavior |
|---|---|---|
| 📝 List (shorthand) | `["pr-review" "commit"]` | Install only these skills |
| ✅ Include attrset | `{ include = ["pr-review"]; }` | Install only these skills |

An empty list `[]` or `["*"]` installs all available skills.

```nix
# Equivalent — install only specific skills:
skills = ["pr-review" "commit"];
skills = { include = ["pr-review" "commit"]; };
```

> ℹ️ **No `exclude`.** The skills CLI has no exclude flag, so skills.nix doesn't
> expose one. List the skills you want with `include` instead.

### 💡 Full example

```nix
programs.skills.sources = [
  # Simple: install all skills from this repo to all agents
  "wshobson/agents"

  # Include only specific skills, for specific agents
  {
    source = "vercel-labs/agent-skills";
    agents = ["opencode" "claude-code"];
    skills = ["pr-review" "commit"];
  }

  # A pinned ref and subpath within a repo
  {
    source = "anthropics/courses/tree/main/skills";
  }

  # Local path
  {
    source = "~/my-custom-skills";
    agents = ["opencode"];
  }
];
```
