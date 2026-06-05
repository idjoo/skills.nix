# ❄️ skills.nix

Declarative agent skills management for [skills.sh](https://skills.sh) via [Home Manager](https://github.com/nix-community/home-manager). ✨

Manage AI coding agent skills across OpenCode, Claude Code, Cursor, Codex, Gemini CLI, Copilot, Cline, Goose, Windsurf, and 70+ other agents — all from your Nix configuration. 🤖

It's a thin, declarative layer over the official [`skills` CLI](https://github.com/vercel-labs/skills): your Nix config is rendered into `skills add` commands and reconciled on every `home-manager switch`.

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

- 📦 **Declarative** — define skills in your Nix config, reconciled on every activation
- 🤖 **70+ agents** — install to all detected agents at once, or target specific ones
- 🌍 **Any source** — GitHub/GitLab/HuggingFace, refs & subpaths, git URLs, local paths
- 🔗 **Two install modes** — symlink (default, space-efficient) or copy
- 🧹 **Declarative ownership** — global skills always match your config; dropped sources are removed
- ⚡ **Change-gated** — skips entirely when your config hasn't changed (no network)
- 🔄 **Auto-update** — optionally runs `skills update` after reconciling
- 📡 **Offline-safe** — gracefully skips when no network is available

> ⚠️ While enabled, your **global** agent skills are fully managed by Nix —
> skills added manually with `npx skills add … -g` are removed on the next switch.
> Declare them in `programs.skills.sources` instead.

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

Whatever the upstream [`skills` CLI](https://github.com/vercel-labs/skills)
supports — 70+ agents including OpenCode, Claude Code, Cursor, Codex, Gemini CLI,
GitHub Copilot, Cline, Goose, Windsurf, and many more. Use `["*"]` to target all
detected agents, or list specific names in `defaultAgents` / a source's `agents`.

## 📄 License

[MIT](LICENSE)
