# 💡 Examples

## 🟢 Minimal setup

Install all skills from a single repo to every agent:

```nix
{
  programs.skills = {
    enable = true;
    sources = [ "wshobson/agents" ];
  };
}
```

## 📚 Multiple sources

```nix
{
  programs.skills = {
    enable = true;
    sources = [
      "wshobson/agents"
      "vercel-labs/agent-skills"
      "anthropics/agent-skills"
    ];
  };
}
```

## 🎯 Target specific agents

Only install to OpenCode and Claude Code:

```nix
{
  programs.skills = {
    enable = true;
    defaultAgents = ["opencode" "claude-code"];
    sources = [ "wshobson/agents" ];
  };
}
```

## 🍒 Cherry-pick specific skills

Install only certain skills from a large repo:

```nix
{
  programs.skills = {
    enable = true;
    sources = [
      {
        source = "vercel-labs/agent-skills";
        skills = ["pr-review" "commit" "test-driven-development"];
      }
    ];
  };
}
```

## 🚫 Exclude unwanted skills

Install everything from a repo *except* certain skills:

```nix
{
  programs.skills = {
    enable = true;
    sources = [
      {
        source = "vercel-labs/agent-skills";
        skills = { exclude = ["deprecated-skill" "experimental-feature"]; };
      }
    ];
  };
}
```

## 🔀 Mix default and per-source agents

```nix
{
  programs.skills = {
    enable = true;
    defaultAgents = ["opencode"];  # Most skills go to OpenCode only

    sources = [
      # Uses defaultAgents (OpenCode only)
      "wshobson/agents"

      # Override: install to all agents
      {
        source = "vercel-labs/agent-skills";
        agents = ["*"];
        skills = ["commit"];
      }

      # Override: Claude Code only
      {
        source = "anthropics/agent-skills";
        agents = ["claude-code"];
      }
    ];
  };
}
```

## 📋 Use copy mode instead of symlinks

```nix
{
  programs.skills = {
    enable = true;
    mode = "copy";
    sources = [ "wshobson/agents" ];
  };
}
```

## 🛠️ Local skill development

Point to a local directory for skills you're developing:

```nix
{
  programs.skills = {
    enable = true;
    sources = [
      # Remote skills
      "wshobson/agents"

      # Your local skills (use symlink mode for live editing)
      {
        source = "~/projects/my-agent-skills";
        agents = ["opencode"];
      }
    ];
  };
}
```

## ⏸️ Disable auto-update

Skip running `skills update` after installation:

```nix
{
  programs.skills = {
    enable = true;
    autoUpdate = false;
    sources = [ "wshobson/agents" ];
  };
}
```

## 🖥️ NixOS module integration (via Home Manager)

Full flake example:

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    skills-nix.url = "github:idjo/skills.nix";
  };

  outputs = { nixpkgs, home-manager, skills-nix, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager.users.myuser = {
            imports = [ skills-nix.homeModules.default ];

            programs.skills = {
              enable = true;
              sources = [
                "wshobson/agents"
                {
                  source = "vercel-labs/agent-skills";
                  agents = ["opencode" "claude-code"];
                  skills = ["pr-review" "commit"];
                }
              ];
            };
          };
        }
      ];
    };
  };
}
```

## 🏠 Standalone Home Manager (without NixOS)

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    skills-nix.url = "github:idjo/skills.nix";
  };

  outputs = { nixpkgs, home-manager, skills-nix, ... }: {
    homeConfigurations."myuser" = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        skills-nix.homeModules.default
        {
          programs.skills = {
            enable = true;
            sources = [ "wshobson/agents" ];
          };
        }
      ];
    };
  };
}
```
