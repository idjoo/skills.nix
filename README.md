# ❄️ skills.nix

Declarative agent skills management for [skills.sh](https://skills.sh) via [Home Manager](https://github.com/nix-community/home-manager). ✨

Manage AI coding agent skills across OpenCode, Claude Code, Cursor, Codex, Gemini CLI, Copilot, Amp, Cline, Goose, Roo, Windsurf, Trae, Kilo, Kiro CLI, Droid, and more — all from your Nix configuration. 🤖

## 🚀 Quick Start

Add the flake input and enable the module:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    skills-nix.url = "github:idjo/skills.nix";
  };
}
```

```nix
# home.nix
{ inputs, ... }: {
  imports = [ inputs.skills-nix.homeModules.default ];

  programs.skills = {
    enable = true;
    sources = [
      "wshobson/agents"
      "vercel-labs/agent-skills"
    ];
  };
}
```

That's it! Skills are installed automatically on every `home-manager switch`. 🎉

## ✨ Features

- 📦 **Declarative** — define skills in your Nix config, they're reconciled on every activation
- 🤖 **Multi-agent** — install to all supported agents at once, or target specific ones
- ⚡ **Smart caching** — skips re-cloning repos when the remote hasn't changed
- 🔗 **Two install modes** — symlink (default, space-efficient) or copy
- 🧹 **Auto-cleanup** — removed sources are cleaned up automatically
- 🔄 **Auto-update** — optionally runs `skills update` after installation
- 📡 **Offline-safe** — gracefully skips when no network is available

## 📚 Documentation

| Document | Description |
|---|---|
| 📖 [Getting Started](docs/getting-started.md) | Installation, prerequisites, and first setup |
| ⚙️ [Configuration](docs/configuration.md) | Full options reference for `programs.skills` |
| 💡 [Examples](docs/examples.md) | Real-world configuration examples |
| 🔧 [How It Works](docs/how-it-works.md) | Architecture, install modes, and lifecycle |
| 🩺 [Troubleshooting](docs/troubleshooting.md) | Common issues and solutions |

> 💻 For the standalone skills CLI, see the official repo: [**vercel-labs/skills**](https://github.com/vercel-labs/skills)

## 🤖 Supported Agents

| Agent | Global Skills Directory |
|---|---|
| OpenCode | `~/.config/opencode/skills/` |
| Claude Code | `~/.claude/skills/` |
| Cursor | `~/.cursor/skills/` |
| Codex | `~/.codex/skills/` |
| Gemini CLI | `~/.gemini/skills/` |
| GitHub Copilot | `~/.copilot/skills/` |
| Amp | `~/.config/agents/skills/` |
| Antigravity | `~/.gemini/antigravity/skills/` |
| Cline | `~/.cline/skills/` |
| Goose | `~/.config/goose/skills/` |
| Roo | `~/.roo/skills/` |
| Windsurf | `~/.codeium/windsurf/skills/` |
| Trae | `~/.trae/skills/` |
| Kilo | `~/.kilocode/skills/` |
| Kiro CLI | `~/.kiro/skills/` |
| Droid | `~/.factory/skills/` |

## 📄 License

[MIT](LICENSE)
