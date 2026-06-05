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

Skills are discovered and installed to all your agent directories automatically. 🎉

## 🔄 What happens on activation

When you run `home-manager switch`, the module reconciles your config via the
`skills` CLI:

1. ⏭️ Skips entirely if your `programs.skills` config hasn't changed
2. 📡 Checks for network connectivity (skips gracefully if offline)
3. 🧹 Clears the current global skills (`skills remove --all -g -y`)
4. 📦 Installs each source (`skills add <source> -g -y …`)
5. 🔄 Optionally runs `skills update -g -y` to pull upstream changes

> ⚠️ While enabled, your global agent skills are **fully managed by Nix** —
> manage them through `programs.skills.sources`, not `npx skills add … -g`.

> 💻 The module also adds the `skills` CLI to your PATH. For CLI usage and documentation, see [**vercel-labs/skills**](https://github.com/vercel-labs/skills).

## ➡️ Next steps

- ⚙️ [Configuration reference](configuration.md) — all available options
- 💡 [Examples](examples.md) — real-world configurations
- 🔧 [How it works](how-it-works.md) — architecture deep dive
