# 🩺 Troubleshooting

## 📦 Skills not installing

**🔍 Symptom:** `home-manager switch` completes but no skills appear in agent directories.

**📡 Check network:** The installer skips silently when offline. Look for:
```
[skip] No network — run 'install-skills' later
```

**✅ Fix:** Run `install-skills` manually once you have network access.

---

**🔍 Symptom:** Nothing happens on switch even though you changed something.

**💡 Cause:** Only changes to your `programs.skills` config trigger a reconcile
(the change gate compares the generated commands file). Editing a skill upstream
doesn't change your config.

**✅ Fix:** Force a full reconcile:
```bash
install-skills --force
```

## ⚠️ Manually-added global skills disappear

**🔍 Symptom:** Skills you installed with `npx skills add … -g` vanish after a
`home-manager switch`.

**💡 Cause:** This is intentional. While `programs.skills.enable = true`, your
global skills are **fully managed by Nix** — every reconcile wipes and rebuilds
them from `programs.skills.sources`.

**✅ Fix:** Add those skills to `programs.skills.sources` so they're declared.

## 🐙 GitHub rate limits

**🔍 Symptom:** `skills add`/`check` fails with HTTP 403 or rate-limit errors,
especially with many sources.

**💡 Cause:** Anonymous GitHub API requests are rate-limited.

**✅ Fix:** Provide a token — the CLI honors `GITHUB_TOKEN` / `GH_TOKEN` (and
`gh auth token`). Make sure one is present in the environment Home Manager runs
in, e.g. via `home.sessionVariables` or your shell profile:
```nix
home.sessionVariables.GITHUB_TOKEN = "…";  # or source it from a secret manager
```

## 🔗 Symlinks not working

**🔍 Symptom:** An agent reports missing skills, but `~/.agents/skills/` has the files.

**🔎 Check:** Verify the agent's skill links are intact:
```bash
ls -la ~/.config/opencode/skills/
```

**✅ Fix:** Re-run the installer, or switch to copy mode:
```bash
install-skills --force
```
```nix
programs.skills.mode = "copy";
```

## 🔍 No skills found

**🔍 Symptom:** A source installs nothing.

**💡 Cause:** The source has no valid `SKILL.md` files, or your `skills` filter
names don't match. A valid `SKILL.md` needs `name` and `description` frontmatter:
```markdown
---
name: skill-name
description: What this skill does
---
```

**🎯 If using a `skills` filter:** Ensure the names in `skills = [...]` match the
`name` field in each `SKILL.md` (case-insensitive). Inspect available skills with:
```bash
skills add owner/repo --list
```

## 🔄 Reset state

**📍 Marker file:** `${XDG_STATE_HOME:-$HOME/.local/state}/skills-nix/applied`
(skills.nix's change gate — not skill data).

**📍 CLI lock file:** `${XDG_STATE_HOME:-$HOME/.local/state}/skills/.skill-lock.json`
or `~/.agents/.skill-lock.json` (the skills CLI's own tracking).

**🔄 Force a clean reconcile:**
```bash
install-skills --force
```

## 🏠 Home Manager activation errors

**🔍 Symptom:** `home-manager switch` fails with an error related to skills.

**🔎 Inspect the generated commands:**
```bash
cat /nix/store/*-skills-commands.sh
```

**💡 Common issues:**
- ❌ Invalid source string in `programs.skills.sources`
- ❌ Type mismatch in option values (e.g. string where list is expected)

**🐛 Debug:** Run `home-manager switch --show-trace` for full error details.

## 🐰 Runtime issues (Bun / git)

**🔍 Symptom:** The `skills` command itself errors out.

**💡 Cause:** The CLI runs under [Bun](https://bun.sh/) and shells out to `git`
(both provided by the package). On a CLI version bump, Bun-vs-Node differences
can occasionally surface.

**✅ Fix:** Report it upstream, and as a workaround pin `programs.skills.package`
to a previous working derivation.

## ⚡ Performance

**🐌 Slow activation:** Many sources mean many `skills add` calls. Consider:

- 🎯 Using a `skills` filter to install only what you need
- 🔑 Setting `GITHUB_TOKEN` to avoid rate-limit backoff
- 📡 Ensuring good network connectivity

**💿 Disk usage:** In symlink mode only one copy of each skill is stored; in copy
mode each agent gets its own. Check usage:
```bash
du -sh ~/.agents/skills/
```
