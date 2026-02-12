# 🩺 Troubleshooting

## 📦 Skills not installing

**🔍 Symptom:** `home-manager switch` completes but no skills appear in agent directories.

**📡 Check network:** The installer skips silently when offline. Look for:
```
[skip] No network — run 'install-skills' later
```

**✅ Fix:** Run `install-skills` manually once you have network access.

---

**🔍 Symptom:** Source is skipped as "unchanged."

**💡 Cause:** The remote commit hash matches the cached one. The source repo hasn't been updated.

**✅ Fix:** Force re-install:
```bash
install-skills --force
```

Or delete the state file to reset:
```bash
rm ~/.local/state/skills-nix/managed.json
install-skills
```

## 🔗 Symlinks not working

**🔍 Symptom:** Agent reports missing skills, but `~/.agents/skills/` has the files.

**🔎 Check:** Verify symlinks are intact:
```bash
ls -la ~/.config/opencode/skills/
```

Broken symlinks may appear as red entries. This can happen if the canonical directory was moved or deleted.

**✅ Fix:** Re-run the installer:
```bash
install-skills --force
```

Or switch to copy mode in your config:
```nix
programs.skills.mode = "copy";
```

## ⚠️ "Unknown agent" warnings

**🔍 Symptom:** Installer logs `unknown agent: <name>`.

**💡 Cause:** The agent name in your config doesn't match a known agent identifier.

**📝 Valid names:** `opencode`, `claude-code`, `cursor`, `codex`, `gemini-cli`, `github-copilot`, `amp`, `antigravity`, `cline`, `goose`, `roo`, `windsurf`, `trae`, `kilo`, `kiro-cli`, `droid`

**✅ Fix:** Use the exact agent name from the list above. Use `["*"]` to target all agents.

## 🔍 "No skills found" warnings

**🔍 Symptom:** `no skills found in <source>`

**💡 Cause:** The source repository doesn't contain any valid `SKILL.md` files, or the files lack required frontmatter (`name` and `description`).

**🔎 Check:** A valid `SKILL.md` must have:
```markdown
---
name: skill-name
description: What this skill does
---

Content...
```

**🎯 If using `skills` filter:** Ensure the skill names in your `skills = [...]` list match the `name` field in the `SKILL.md` frontmatter (case-insensitive).

## 🐙 Git clone failures

**🔍 Symptom:** `failed to process <source>: ...`

**💡 Common causes:**
- 🚫 Repository doesn't exist or is private
- ❌ Git is not in PATH
- ⏱️ Network timeout (clone has a 30-second timeout)

**✅ Fix:**
- Verify the repo URL: `git ls-remote https://github.com/owner/repo.git`
- For private repos, ensure SSH keys or credentials are configured 🔑
- Check that `git` is available: `which git`

## 💾 State file issues

**📍 Location:** `~/.local/state/skills-nix/managed.json`

**🔄 Reset state completely:**
```bash
rm ~/.local/state/skills-nix/managed.json
```

**🔎 Inspect current state:**
```bash
cat ~/.local/state/skills-nix/managed.json | jq .
```

## 🏠 Home Manager activation errors

**🔍 Symptom:** `home-manager switch` fails with an error related to skills.

**🔎 Check the manifest:** The module generates a manifest JSON. You can inspect it:
```bash
cat /nix/store/*-skills-manifest.json
```

**💡 Common issues:**
- ❌ Invalid source format in `programs.skills.sources`
- ❌ Type mismatch in option values (e.g. string where list is expected)

**🐛 Debug:** Run `home-manager switch --show-trace` for full error details.

## 🔄 Skills not updating

**🔍 Symptom:** Skills are installed but out of date.

**💡 Cause:** `autoUpdate` may be disabled, or the source commit hash hasn't changed.

**✅ Fix:**
```bash
# Force reinstall
install-skills --force
```

**Or enable auto-update:**
```nix
programs.skills.autoUpdate = true;  # This is the default
```

> 💻 For manual CLI updates, see the [skills CLI docs](https://github.com/vercel-labs/skills).

## ⚡ Performance

**🐌 Slow activation:** The installer clones repos in parallel, but large repos or many sources can still take time. Consider:

- 🎯 Using `skills` filter to install only the skills you need
- 📂 Setting `fullDepth = false` if skills are at the top level
- 📡 Ensuring good network connectivity

**💿 Disk usage:** In symlink mode, only one copy of each skill is stored. In copy mode, each agent gets its own copy. Check usage:
```bash
du -sh ~/.agents/skills/
```
