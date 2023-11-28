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

				GOPRIVATE			= "bb.eng.venafi.com,gitlab.com/venafi,go.venafi.cloud";

				AWS_REGION			= "us-west-2";
				AWS_PROFILE			= "trustnet-dev";
				AWS_SSO_START_URL	= "https://d-926708eb5a.awsapps.com/start#";

				buildInputs = with pkgs; [
					(
						pkgs.writeScriptBin "aws-w" ''
                            #! ${pkgs.bash}/bin/bash

							mkdir -p "$FAKE_HOME_DIR"
							HOME="$FAKE_HOME_DIR" exec ${pkgs.awscli2}/bin/aws "$@"
                            ''
					)
					(
						pkgs.writeScriptBin "kubectl" ''
                            #! ${pkgs.bash}/bin/bash

							mkdir -p "$FAKE_HOME_DIR/.kube/cache"
							HOME="$FAKE_HOME_DIR" exec ${pkgs.kubectl}/bin/kubectl \
                                --cache-dir="$FAKE_HOME_DIR/.kube/cache" "$@"
                            ''
					)
					(
						pkgs.writeScriptBin "k9s" ''
                            #! ${pkgs.bash}/bin/bash

							mkdir -p "$FAKE_HOME_DIR"
							HOME="$FAKE_HOME_DIR" exec ${pkgs.k9s}/bin/k9s "$@"
                            ''
					)
					awscli2
					kube-linter
					kubernetes-helm
					k9s

					docker
					yq
					jq
				];

				awsconfigskel = builtins.toFile "aws_config_file" ''
                    [default]
                    output = json
                    region = ${AWS_REGION}

                    [profile trustnet-dev]
                    sso_session = vaas
                    sso_account_id = 497086895112
                    sso_role_name = Vaas.Developer
                    region = ${AWS_REGION}
                    output = json

                    [sso-session vaas]
                    sso_start_url = https://d-926708eb5a.awsapps.com/start#/
                    sso_region = ${AWS_REGION}
                    sso_registration_scopes = sso:account:access
                    '';

				shellHook = ''
					export FAKE_HOME_DIR="$(pwd)"

                    if [ ! -d $FAKE_HOME_DIR/.aws ]; then
                        mkdir -p $FAKE_HOME_DIR/.aws
					fi

					rm -f $FAKE_HOME_DIR/.aws/config
					cp ${awsconfigskel} $FAKE_HOME_DIR/.aws/config

					aws-w sts get-caller-identity --profile ${AWS_PROFILE} --no-cli-pager >/dev/null 2>&1
					if [[ $? -eq 0 ]]; then
						echo "Logged in"
					else
						echo "Logging in to AWS..."
						aws-w sso login --profile ${AWS_PROFILE}
                        aws-w eks --region ${AWS_REGION} update-kubeconfig --name dev01 --role-arn arn:aws:iam::497086895112:role/eks/dev01-KubernetesDevelopers
					fi
					kubectl config set-context --current --namespace=$DEVSTACK
				'';
			};
		}
	);
}
