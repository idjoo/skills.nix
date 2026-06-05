# 🔧 How It Works

## 🏗️ Architecture

skills.nix is a thin, declarative layer over the official
[`skills` CLI](https://github.com/vercel-labs/skills). It has two components:

```
flake.nix
  ├── module.nix    🏠 Home Manager module (Nix options + activation script)
  └── package.nix   📦 Nix derivation wrapping the skills CLI from npm
```

There is **no custom installer** — the module generates plain `skills` commands
and lets the CLI do all the work (discovery, cloning, symlinking, agent
detection, update tracking). This means you get every source type and every
agent the CLI supports, for free, and it stays correct as the CLI evolves.

### 🏠 Module (`module.nix`)

Defines `programs.skills.*` options and wires them into Home Manager:

- 📝 Renders your `sources` into a list of `skills add …` commands, written to a
  file in the Nix store (`skills-commands.sh`)
- 🛡️ Creates an `install-skills` script that reconciles your config (with a
  network check and an unchanged-config fast path)
- 🪝 Registers a Home Manager **activation hook** that runs after `writeBoundary`

### 📦 Package (`package.nix`)

Wraps the official [`skills` CLI](https://github.com/vercel-labs/skills) as a Nix derivation:

- ⬇️ Downloads the tarball from the npm registry
- 🐰 Uses [Bun](https://bun.sh/) as the JavaScript runtime, with `git` on PATH
- 🔧 Provides the `skills` binary

## 🔄 Reconciliation (declarative ownership)

When `programs.skills.enable = true`, your **global** agent skills are fully
owned by Nix. On each `home-manager switch`, `install-skills` runs:

1. ⏭️ **Change gate** — compares the Nix store path of the generated commands
   file against the last-applied path. If unchanged (and `--force` not passed),
   it does nothing but an optional `skills update` — no network, no churn.
2. 📡 **Network check** — if `github.com` is unreachable, it skips gracefully.
3. 🧹 **Wipe** — `skills remove --all -g -y` clears all global skills.
4. 📦 **Rebuild** — runs each generated `skills add <source> -g -y …` line.
5. 🔄 **Update** — if `autoUpdate`, runs `skills update -g -y`.
6. 💾 **Record** — saves the applied store path to the marker file.

The wipe-and-rebuild model guarantees the installed set exactly matches your
config without skills.nix tracking any per-skill state itself.

> ⚠️ **Declarative ownership:** while this module is enabled, global skills you
> add manually with `npx skills add …` will be removed on the next switch.
> Manage them through `programs.skills.sources` instead.

## 🔗 Install Modes

Maps directly to the CLI's behavior:

| Mode | CLI flag | Behavior |
|---|---|---|
| 🔗 `"symlink"` (default) | *(none)* | One canonical copy under `~/.agents/skills`, symlinked into each agent directory. Space-efficient. |
| 📋 `"copy"` | `--copy` | An independent copy in each agent directory. Fully isolated. |

The canonical `~/.agents/skills` directory is managed by the CLI itself —
"universal" agents read from it directly, others get symlinks (or copies).

## 🗂️ State & update detection

skills.nix keeps **no skill state of its own**. The CLI maintains a global lock
file (`$XDG_STATE_HOME/skills/.skill-lock.json`, falling back to
`~/.agents/.skill-lock.json`) recording each skill's source and GitHub tree SHA.
`skills check` / `skills update` use that hash to detect and pull upstream
changes.

The only file skills.nix writes is a tiny change-gate marker at
`$XDG_STATE_HOME/skills-nix/applied` holding the last-applied store path. Delete
it (or run `install-skills --force`) to force a full reconcile.

## 🔎 Skill Discovery

Discovery is handled entirely by the CLI. A valid skill is a directory
containing a `SKILL.md` file with YAML frontmatter including `name` and
`description`:

```markdown
---
name: my-skill
description: Does something useful
---

Skill instructions here...
```

The CLI searches sources (roughly two levels deep, with a recursive fallback)
and selects skills by name when you pass a `skills` filter.

## 🔄 Activation Lifecycle

```
home-manager switch
  └── activation.installSkills
        ├── 🧪 Check DRY_RUN (skip if dry run)
        └── ▶️  Run install-skills
              ├── ⏭️  Change gate (skip if config unchanged)
              ├── 📡 Network check (curl github.com)
              ├── 🧹 skills remove --all -g -y
              ├── 📦 skills add … (one per source)
              ├── 🔄 skills update -g -y (optional)
              └── 💾 Save marker
```

## 📡 Offline Behavior

The script checks network connectivity before doing any network work. If
`github.com` is unreachable (e.g. during initial install or on a plane ✈️), it
exits with:

```
[skip] No network — run 'install-skills' later
```

Run `install-skills` manually once connectivity is restored. 🌐
