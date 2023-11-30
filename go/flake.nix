{
	description = "My nix flake to help with various development environments";
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
				name = "go dev shell";

				buildInputs = with pkgs; [
					go_1_20
					gopls
					go-tools
					gotools
					golangci-lint
				];
			};
		}
	);
}
