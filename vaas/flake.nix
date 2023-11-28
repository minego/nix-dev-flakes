{
	description = "My nix flake to help with various development environments";
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
				name = "aws dev shell";

				shellHook = ''
					echo aws
				'';

				buildInputs = with pkgs; [
					awscli2

					kubectl
					kube-linter
					kubernetes-helm
					k9s

					docker
					yq
					jq
				];
			};
		}
	);
}
