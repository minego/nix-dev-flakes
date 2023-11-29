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
					kubernetes-helm

					docker
					rootlesskit

					kube-linter
					yq
					jq

					(
        				# Wrapper for make that ensures docker rootless mode is running
	        			# before running the actual make command.
		        		#
        				# This is a very hacky solution, but it works...
        				pkgs.writeShellScriptBin "make" ''
                            # Start dockerd-rootless
                            dockerd-rootless -G $(id -g) > $VAAS_HOME/dockerd.log 2>&1 &
                            DOCKERD_PID=$!

                            # Wait until it is ready
                            while ! docker info >/dev/null 2>&1; do
                               sleep 0.3
                            done

                            # Run the actual make command
                            ${pkgs.gnumake}/bin/make $@
                            RET=$?

                            # kill dockerd
                            kill $DOCKERD_PID
                            while docker info >/dev/null 2>&1; do
                               sleep 0.3
                            done

                            exit $RET
                        ''
					)
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
                    export VAAS_ENV=$VAAS_HOME/vaas-env
                    mkdir -p $VAAS_HOME

                    ###########################################################
                    # Wrap various tools so that they see $VAAS_HOME as their
                    # home dir, and keep things out of the real home dir
                    ###########################################################
                    rm -rf $VAAS_HOME/bin
                    mkdir $VAAS_HOME/bin
                    export PATH="$VAAS_HOME/bin:$PATH"

                    cp $(which aws) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/aws --set HOME "$VAAS_HOME"

                    cp $(which kubectl) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/kubectl --set HOME "$VAAS_HOME"

                    cp $(which k9s) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/k9s --set HOME "$VAAS_HOME"

                    cp $(which helm) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/helm --set HOME "$VAAS_HOME"

                    cp $(which docker) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/docker --set HOME "$VAAS_HOME" \
                            --set DOCKER_HOST "unix://$VAAS_HOME/docker.sock"

                    cp $(which dockerd) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/dockerd --set HOME "$VAAS_HOME"

                    cp $(which dockerd-rootless) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/dockerd-rootless --set HOME "$VAAS_HOME" \
                            --add-flags "--data-root $VAAS_HOME/docker" \
                            --add-flags "-H unix://$VAAS_HOME/docker.sock"

                    ###########################################################
                    # Prompt for user specific options
                    ###########################################################
                    if [ ! -f "$VAAS_ENV" ]; then
                        if [ ! -n "$DEVSTACK" ]; then
                            read -p "What is your devstack number? (ie dev123): "	DEVSTACK
                        fi
                        if [ ! -n "$DOCKER_USERNAME" ]; then
                            read -p "Enter your docker hub username: "				DOCKER_USERNAME
                        fi
                        if [ ! -n "$DOCKER_TOKEN" ]; then
                            read -p "Enter your docker access token: " -s			DOCKER_TOKEN
                            echo
                        fi
                        if [ ! -n "$GLAB_TOKEN" ]; then
                            read -p "Enter your private gitlab access token: " -s	GLAB_TOKEN
                            echo
                        fi

                        # Save the options do we don't have to prompt next time
                        echo "DEVSTACK=\"$DEVSTACK\""                > "$VAAS_ENV"
                        echo "DOCKER_USERNAME=\"$DOCKER_USERNAME\"" >> "$VAAS_ENV"
                        echo "DOCKER_TOKEN=\"$DOCKER_TOKEN\""       >> "$VAAS_ENV"
                        echo "GLAB_TOKEN=\"$GLAB_TOKEN\""           >> "$VAAS_ENV"
                    else
                        # Load the previously stored options
                        . "$VAAS_ENV"
                    fi

                    ###########################################################
                    # Login to docker
                    ###########################################################
                    echo "$DOCKER_TOKEN" | docker login -u "$DOCKER_USERNAME" --password-stdin
                    if [[ $? -ne 0 ]]; then
                        echo "ERROR: Failed to login to docker."
                        rm -i "$VAAS_ENV"
                        exit 1
                    fi

                    ###########################################################
                    # Ensure we have the helm repo added
                    ###########################################################
                    helm repo add --force-update --username venafi --password $GLAB_TOKEN venafi https://gitlab.com/api/v4/projects/50431710/packages/helm/stable
                    if [[ $? -ne 0 ]]; then
                        echo "ERROR: Failed to add helm repo."
                        rm -i "$VAAS_ENV"
                        exit 1
                    fi

                    ###########################################################
                    # Setup the base AWS configuration (based on the skeleton above)
                    ###########################################################
                    mkdir -p $VAAS_HOME/.aws
                    rm -f $VAAS_HOME/.aws/config
                    cp ${awsconfigskel} $VAAS_HOME/.aws/config

                    ###########################################################
                    # Test AWS access; Login again if needed
                    ###########################################################
                    aws sts get-caller-identity --profile ${AWS_PROFILE} --no-cli-pager >/dev/null 2>&1
                    if [[ $? -eq 0 ]]; then
                        echo "Already logged into AWS"
                    else
                        echo "Logging in to AWS..."
                        aws sso login --profile ${AWS_PROFILE}

                        if [[ $? -ne 0 ]]; then
                            echo "ERROR: Failed to login to AWS."
                            rm -i "$VAAS_ENV"
                            exit 1
                        fi
                    fi

                    aws eks --region ${AWS_REGION} update-kubeconfig --name dev01 --role-arn arn:aws:iam::497086895112:role/eks/dev01-KubernetesDevelopers
                    kubectl config set-context --current --namespace=$DEVSTACK

                    echo ""
                    echo "SUCCESS: VaaS development environment is now ready."
                    echo ""
                    '';
			};
		}
	);
}
