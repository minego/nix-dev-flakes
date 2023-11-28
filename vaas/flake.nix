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
				name = "vaas dev";

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

				GOPRIVATE			= "bb.eng.venafi.com,gitlab.com/venafi,go.venafi.cloud";
				AWS_REGION			= "us-west-2";
				AWS_PROFILE			= "vaas-developer";
				AWS_SSO_START_URL	= "https://d-926708eb5a.awsapps.com/start#";

				awsconfigskel = builtins.toFile "aws_config_file" ''
                    [default]
                    output = json
                    region = ${AWS_REGION}

                    [profile ${AWS_PROFILE}]
                    sso_start_url = https://d-926708eb5a.awsapps.com/start#
                    sso_region = ${AWS_REGION}
                    sso_account_id = 497086895112
                    sso_role_name = VaaS.Developer
                    region = ${AWS_REGION}
                    output = json
                    sso_session = ${AWS_PROFILE}

                    [sso-session ${AWS_PROFILE}]
                    sso_region = ${AWS_REGION}
                    sso_registration_scopes = sso:account:access
                    sso_start_url = https://d-926708eb5a.awsapps.com/start#
                    '';

				shellHook = ''
					echo "The aws config skeleton: ${awsconfigskel}"
				'';
			};
		}
	);
}
