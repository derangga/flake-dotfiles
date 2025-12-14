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
      configuration =
        { pkgs, config, ... }:
        {
          system.primaryUser = "derangga";
          nixpkgs.config.allowUnfree = true;

          environment.systemPackages = [
            pkgs.android-tools
            pkgs.colima
            pkgs.docker-compose
            pkgs.eza
            pkgs.fd
            pkgs.fnm
            pkgs.ffmpeg
            pkgs.fzf
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
            pkgs.ripgrep
            pkgs.rbenv
          ];

          fonts.packages = [
            pkgs.nerd-fonts.jetbrains-mono
          ];

          # Basic zsh enable (Home Manager will handle the detailed config)
          programs.zsh.enable = true;

          # Declare the user - required for home manager on nix-darwin
          users.users.derangga = {
            name = "derangga";
            home = "/Users/derangga";
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

          # Necessary for using flakes on this system
          nix.settings.experimental-features = "nix-command flakes";

          # Set Git commit hash for darwin-version
          system.configurationRevision = self.rev or self.dirtyRev or null;

          # Used for backwards compatibility
          system.stateVersion = 6;

          # The platform the configuration will be used on
          nixpkgs.hostPlatform = "aarch64-darwin";
        };
    in
    {
      darwinConfigurations."maclop" = nix-darwin.lib.darwinSystem {
        modules = [
          configuration
          nix-homebrew.darwinModules.nix-homebrew
          {
            nix-homebrew = {
              enable = true;
              enableRosetta = true;
              user = "derangga";
              autoMigrate = true;
            };
          }

          home-manager.darwinModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.derangga =
              { pkgs, ... }:
              {
                home.stateVersion = "25.11";
                home.username = "derangga";
                home.homeDirectory = "/Users/derangga";

                home.packages = [
                  pkgs.zsh-powerlevel10k
                ];

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
                    ls = "eza --icons --color=always --group-directories-first";
                    ll = "eza -alF --icons --color=always --group-directories-first";
                    lg = "lazygit";
                    vim = "nvim";
                  };

                  initContent = ''
                    # Add any custom zsh configuration here
                    export EDITOR=nvim

                    # Powerlevel10k theme
                    source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme

                    # To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
                    [[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
                  '';
                };
              };
          }
        ];
      };
      darwinPackages = self.darwinConfigurations."maclop".pkgs;
    };
}
