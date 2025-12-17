{
  description = "derangga nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{
      self,
      nix-darwin,
      nixpkgs,
      nix-homebrew,
      home-manager,
    }:
    let
      # Helper function to create configurations for different users
      mkDarwinConfig =
        { hostname, username }:
        let
          configuration =
            { pkgs, config, ... }:
            {
              system.primaryUser = username;
              nixpkgs.config.allowUnfree = true;

              environment.systemPackages = [
                pkgs.android-tools
                pkgs.bun
                pkgs.btop
                pkgs.colima
                pkgs.docker
                pkgs.docker-compose
                pkgs.eza
                pkgs.fd
                pkgs.fnm
                pkgs.ffmpeg
                pkgs.gcc
                pkgs.gnupg
                pkgs.go
                pkgs.git
                pkgs.lazygit
                pkgs.lua
                pkgs.mkalias
                pkgs.neovim
                pkgs.nixfmt
                pkgs.javaPackages.compiler.openjdk17
                pkgs.jq
                pkgs.pm2
                pkgs.pyenv
                pkgs.ripgrep
                pkgs.rbenv
              ];

              fonts.packages = [
                pkgs.nerd-fonts.jetbrains-mono
              ];

              programs.zsh.enable = true;

              users.users.${username} = {
                name = username;
                home = "/Users/${username}";
              };

              homebrew = {
                enable = true;
                onActivation.cleanup = "zap";
              };

              system.activationScripts.applications.text =
                let
                  env = pkgs.buildEnv {
                    name = "system-applications";
                    paths = config.environment.systemPackages;
                    pathsToLink = [ "/Applications" ];
                  };
                in
                pkgs.lib.mkForce ''
                  # Set up applications
                  echo "setting up /Applications..." >&2
                  rm -rf /Applications/Nix\ Apps/
                  mkdir -p /Applications/Nix\ Apps/
                  find ${env}/Applications -maxdepth 1 -type l -exec readlink '{}' + |
                  while read -r src; do
                    app_name=$(basename "$src")
                    echo "copying $src" >&2
                    ${pkgs.mkalias}/bin/mkalias "$src" "/Applications/Nix\ Apps/$app_name"
                  done
                '';

              nix.settings.experimental-features = "nix-command flakes";
              system.configurationRevision = self.rev or self.dirtyRev or null;
              system.stateVersion = 6;
              nixpkgs.hostPlatform = "aarch64-darwin";
            };
        in
        nix-darwin.lib.darwinSystem {
          modules = [
            configuration
            nix-homebrew.darwinModules.nix-homebrew
            {
              nix-homebrew = {
                enable = true;
                enableRosetta = true;
                user = username;
                autoMigrate = true;
              };
            }

            home-manager.darwinModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.users.${username} =
                { pkgs, ... }:
                {
                  home.stateVersion = "25.11";
                  home.username = username;
                  home.homeDirectory = "/Users/${username}";

                  home.packages = [
                    pkgs.dbeaver-bin
                    pkgs.postman
                    pkgs.aerospace
                  ];

                  programs.fzf = {
                    enable = true;
                    enableZshIntegration = true;
                  };

                  programs.starship = {
                    enable = true;
                  };

                  programs.vscode = {
                    enable = true;
                  };

                  programs.zsh = {
                    enable = true;
                    enableCompletion = true;
                    autosuggestion.enable = true;

                    oh-my-zsh = {
                      enable = true;
                      plugins = [
                        "git"
                        "fzf"
                      ];
                    };

                    shellAliases = {
                      drb = "sudo darwin-rebuild switch --flake ~/nix#${hostname}";
                      ls = "eza --icons --color=always --group-directories-first";
                      ll = "eza -alF --icons --color=always --group-directories-first";
                      lg = "lazygit";
                      vim = "nvim";
                    };

                    initContent = ''
                      export EDITOR=nvim

                      eval "$(starship init zsh)"
                      eval "$(fnm env --use-on-cd --shell zsh)"
                    '';
                  };

                };
            }
          ];
        };
    in
    {
      # Personal laptop configuration
      darwinConfigurations."maclop" = mkDarwinConfig {
        hostname = "maclop";
        username = "derangga";
      };

      # Work laptop configuration
      darwinConfigurations."worklop" = mkDarwinConfig {
        hostname = "worklop";
        username = "sociolla";
      };

      # Default package output for personal laptop
      darwinPackages = self.darwinConfigurations."maclop".pkgs;
    };
}
