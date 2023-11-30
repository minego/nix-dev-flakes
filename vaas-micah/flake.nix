{
	description = "My settings for vaas dev";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
		utils.url = "github:numtide/flake-utils";
	};

	outputs = { self, nixpkgs, ... }@inputs: inputs.utils.lib.eachDefaultSystem (system:
		let
			pkgs = import nixpkgs { inherit system; };
		in {
			# This block here is used when running `nix develop`
			devShells.default = pkgs.mkShellNoCC rec {
				name = "vaas dev micah";

				gitconfig = builtins.toFile "gitconfig" ''
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
                    [url "git@gitlab.com:venafi/"]
                        insteadOf = https://gitlab.com/venafi/
                    [init]
                        defaultBranch = main
                    [push]
                        autoSetupRemote = true
                    '';

				GIT_CONFIG_SYSTEM	= "/dev/null";
				GIT_CONFIG_GLOBAL	= "${gitconfig}";
				DEVSTACK			= "dev157";
				HTTPS_PROXY			= "http://prosser.minego.net:8118";

				buildInputs = with pkgs; [
					git
					git-lfs
				];
			};
		}
	);
}
