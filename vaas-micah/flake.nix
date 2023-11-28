{
	description = "My settings for vaas dev";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		utils.url = "github:numtide/flake-utils";
	};

	outputs = { self, nixpkgs, ... }@inputs: inputs.utils.lib.eachSystem [
		"x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"
	] (system:
		let
			pkgs = import nixpkgs { inherit system; };
		in {
			# This block here is used when running `nix develop`
			devShells.default = pkgs.mkShellNoCC rec {
				name = "vaas dev micah";

				GIT_CONFIG_HOME		= ".config/git/";
				DEVSTACK			= "dev157";
				HTTPS_PROXY			= "http://prosser.minego.net:8118";

				gitconfig = builtins.toFile "aws_config_file" ''
                    [user]
                        email = micah.gorrell@venafi.com
                        name = Micah N Gorrell
                    [filter "lfs"]
                        clean = git-lfs clean -- %f
                        smudge = git-lfs smudge -- %f
                        process = git-lfs filter-process
                        required = true
                    [pull]
                        rebase = true
                    [url "git@gitlab.com:"]
                        insteadOf = https://gitlab.com/
                    [init]
                        defaultBranch = main
                    [push]
                        autoSetupRemote = true
                    '';

				buildInputs = with pkgs; [
					(pkgs.writeScriptBin "git" ''
                        #!${pkgs.bash}/bin/bash
						export GIT_CONFIG_NOSYSTEM="1"
						export HOME="${GIT_CONFIG_HOME}"
                        exec ${pkgs.git}/bin/git "$@"
					'')
					git-lfs
				];
			};
		}
	);
}
