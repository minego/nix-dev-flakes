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

				nativeBuildInputs = with pkgs; [
					makeBinaryWrapper
				];

				buildInputs = with pkgs; [
					awscli2
					kubectl
					k9s
					kube-linter
					kubernetes-helm

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
export VAAS_HOME=$(pwd)/.vaas_home
mkdir -p $VAAS_HOME


# Make wrapped copies of specific binaries that will run with their $HOME
# environment variable overwritten to be a subdir of this environment
rm -rf $VAAS_HOME/bin
mkdir $VAAS_HOME/bin
export PATH="$VAAS_HOME/bin:$PATH"

cp `which aws` $VAAS_HOME/bin/
wrapProgram $VAAS_HOME/bin/aws --set HOME "$VAAS_HOME"

cp `which kubectl` $VAAS_HOME/bin/
wrapProgram $VAAS_HOME/bin/kubectl --set HOME "$VAAS_HOME"

cp `which k9s` $VAAS_HOME/bin/
wrapProgram $VAAS_HOME/bin/k9s --set HOME "$VAAS_HOME"


# Setup the base AWS configuration in the local dir based on the skeleton
mkdir -p $VAAS_HOME/.aws
rm -f $VAAS_HOME/.aws/config
cp ${awsconfigskel} $VAAS_HOME/.aws/config

# Test AWS access
aws sts get-caller-identity --profile ${AWS_PROFILE} --no-cli-pager >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
	echo "Already logged into AWS"
else
	echo "Logging in to AWS..."
	aws sso login --profile ${AWS_PROFILE}
	aws eks --region ${AWS_REGION} update-kubeconfig --name dev01 --role-arn arn:aws:iam::497086895112:role/eks/dev01-KubernetesDevelopers
fi
kubectl config set-context --current --namespace=$DEVSTACK
'';
			};
		}
	);
}
