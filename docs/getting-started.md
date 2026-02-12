# 📖 Getting Started

## 📋 Prerequisites

- ❄️ [Nix](https://nixos.org/) with flakes enabled
- 🏠 [Home Manager](https://github.com/nix-community/home-manager) (as a flake module)
- 🔀 Git (available in your environment)

## 📦 Installation

### 1️⃣ Add the flake input

In your `flake.nix`, add `skills-nix` as an input:

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    skills-nix.url = "github:idjo/skills.nix";
  };

  outputs = { nixpkgs, home-manager, skills-nix, ... }: {
    homeConfigurations."your-username" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        skills-nix.homeModules.default
        ./home.nix
      ];
    };
  };
}
```

### 2️⃣ Enable and configure

In your Home Manager configuration (e.g. `home.nix`):

```nix
{
  programs.skills = {
    enable = true;
    sources = [
      "wshobson/agents"
    ];
  };
}
```

### 3️⃣ Apply

```bash
home-manager switch
```

Skills are cloned, discovered, and installed to all your agent directories automatically. 🎉

## 🔄 What happens on activation

When you run `home-manager switch`, the module:

1. 📡 Checks for network connectivity (skips gracefully if offline)
2. 🔍 Compares each source repo's remote commit hash against the local cache
3. 📥 Clones only repos that have changed (or are new)
4. 🔎 Discovers all `SKILL.md` files in each repo
5. 📂 Copies skills to `~/.agents/skills/` (canonical location)
6. 🔗 Symlinks (or copies) from each agent's global skills directory
7. 🧹 Removes skills from sources you've dropped from your config
8. 🔄 Optionally runs `skills update` for any additional updates

> 💻 The module also adds the `skills` CLI to your PATH. For CLI usage and documentation, see [**vercel-labs/skills**](https://github.com/vercel-labs/skills).

## ➡️ Next steps

- ⚙️ [Configuration reference](configuration.md) — all available options
- 💡 [Examples](examples.md) — real-world configurations
- 🔧 [How it works](how-it-works.md) — architecture deep dive
