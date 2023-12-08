{
	description = "Nix development environment for Venafi CodeSigning Clients";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
		utils.url = "github:numtide/flake-utils";
	};

	outputs = { self, nixpkgs, ... }@inputs: inputs.utils.lib.eachDefaultSystem (system:
		let
			pkgs = import nixpkgs { inherit system; };
			frameworks = pkgs.darwin.apple_sdk.frameworks;
			stdenv =
				if pkgs.stdenv.isDarwin then
					pkgs.stdenvNoCC
				else if pkgs.stdenv.isLinux then
					pkgs.stdenv
				else
					throw "Unsupported platform";

			buildDeps = with pkgs; [
				libuuid
				doxygen
				cmake
				gdb
			] ++ lib.optionals pkgs.stdenv.isDarwin [
				frameworks.Foundation
				frameworks.Security
				frameworks.Cocoa
				frameworks.CryptoTokenKit

				# Building on macOS requires native xcode tools, which can't be
				# installed automatically as a derivation.
				#
				# This hack relies on having XCode properly installed, and will
				# symlink in the required tools from the host system.
				(runCommand "macvim-build-symlinks" {} ''
					mkdir -p $out/bin
					ln -s /usr/bin/xcrun		$out/bin
					ln -s /usr/bin/xcodebuild	$out/bin
					ln -s /usr/bin/codesign		$out/bin
					ln -s /usr/bin/clang		$out/bin
					ln -s /usr/bin/ar			$out/bin
					ln -s /usr/bin/ranlib		$out/bin
					ln -s /usr/bin/dsymutil		$out/bin
				'')
			];

		in {
			# This block here is used when running `nix develop`
			devShells.default = pkgs.mkShell rec {
				# Update the name to something that suites your project.
				name				= "csc";
				packages			= buildDeps;
				shellHook			= ''
					export LD=$CC
					export CFLAGS="-g3 -ggdb -DDEBUG -O1"
				'';
			};
		}
	);
}
