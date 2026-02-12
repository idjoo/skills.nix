# 🔧 How It Works

## 🏗️ Architecture

skills.nix has three main components:

```
flake.nix
  ├── module.nix      🏠 Home Manager module (Nix options + activation script)
  ├── package.nix      📦 Nix derivation wrapping the skills CLI from npm
  └── lib/install.mjs  ⚙️  Custom declarative installer (runs at activation time)
```

### 🏠 Module (`module.nix`)

Defines `programs.skills.*` options and wires them into Home Manager:

- 📄 Generates a **manifest JSON** from your Nix configuration
- 🛡️ Creates an `install-skills` wrapper script with network checks
- 🪝 Registers a Home Manager **activation hook** that runs after `writeBoundary`

### 📦 Package (`package.nix`)

Wraps the official [`skills` CLI](https://github.com/vercel-labs/skills) as a Nix derivation:

- ⬇️ Downloads the tarball from the npm registry
- 🐰 Uses [Bun](https://bun.sh/) as the JavaScript runtime
- 🔧 Provides two binaries: `skills` (the CLI) and `skills-install` (the declarative installer)

### ⚙️ Installer (`lib/install.mjs`)

The core reconciliation engine. It runs in 5 phases:

1. 🧹 **Remove stale skills** — deletes skills from sources no longer in your config
2. 📥 **Prepare sources** — clones repos or resolves local paths (in parallel)
3. 📦 **Install skills** — discovers `SKILL.md` files, copies/symlinks to agent directories
4. 💾 **Write state** — persists current state to `~/.local/state/skills-nix/managed.json`
5. 🔄 **Update** — optionally runs `skills update` via the CLI

## 🔗 Install Modes

### 🔗 Symlink mode (default)

```
~/.agents/skills/           📂 (canonical — full copies live here)
  ├── commit/
  ├── pr-review/
  └── ...

~/.config/opencode/skills/  🔗 (agent dir — symlinks)
  ├── commit -> ../../../.agents/skills/commit
  ├── pr-review -> ../../../.agents/skills/pr-review
  └── ...

~/.claude/skills/           🔗 (another agent — same symlinks)
  ├── commit -> ../../.agents/skills/commit
  └── ...
```

- 💾 Space-efficient: only one copy of each skill on disk
- 🔄 All agents always see the same version
- 🛡️ Falls back to copy if symlink creation fails

### 📋 Copy mode

```
~/.agents/skills/           📂 (canonical)
  ├── commit/
  └── ...

~/.config/opencode/skills/  📂 (independent copy)
  ├── commit/
  └── ...

~/.claude/skills/           📂 (independent copy)
  ├── commit/
  └── ...
```

- 🏝️ Each agent has its own independent copy
- 💿 More disk usage, but fully isolated

## ⚡ Smart Caching

The installer tracks the Git commit hash of each remote source. On subsequent runs:

1. 🔍 Queries `git ls-remote` for the current remote HEAD
2. 🔄 Compares against the stored hash in `~/.local/state/skills-nix/managed.json`
3. ⏭️ Skips cloning if the hash matches (source unchanged)
4. 💪 Use `install-skills --force` to bypass caching

Local sources always check the local commit hash but don't skip — they're always re-scanned since the directory is already available.

## 🔎 Skill Discovery

A valid skill is a directory containing a `SKILL.md` file with YAML frontmatter including `name` and `description` fields:

```markdown
---
name: my-skill
description: Does something useful
---

Skill instructions here...
```

With `fullDepth = true` (default), the installer recursively searches all subdirectories. With `fullDepth = false`, it only checks the top-level directory and its immediate children.

## 💾 State Management

State is persisted at `~/.local/state/skills-nix/managed.json`:

```json
{
  "owner/repo": {
    "skills": ["skill-a", "skill-b"],
    "agents": ["*"],
    "commitHash": "abc123..."
  }
}
```

This enables:

- ⚡ **Cache invalidation** — skip unchanged repos
- 🧹 **Stale cleanup** — when you remove a source from your config, its skills are removed from disk
- 🛡️ **Crash recovery** — if installation fails for a source, the old state is preserved

## 🔄 Activation Lifecycle

```
home-manager switch
  └── activation.installSkills
        ├── 🧪 Check DRY_RUN (skip if dry run)
        ├── 📡 Network check (curl github.com)
        │     └── ❌ No network? → skip gracefully
        └── ▶️  Run install-skills
              ├── 1️⃣  Phase 1: Remove stale
              ├── 2️⃣  Phase 2: Prepare sources (parallel git clone)
              ├── 3️⃣  Phase 3: Install skills
              ├── 4️⃣  Phase 4: Write state
              └── 5️⃣  Phase 5: Auto-update (optional)
```

## 📡 Offline Behavior

The activation script checks network connectivity before running. If `github.com` is unreachable (e.g. during initial NixOS install or on a plane ✈️), the script exits with a message:

```
[skip] No network — run 'install-skills' later
```

You can manually run `install-skills` later when connectivity is restored. 🌐
