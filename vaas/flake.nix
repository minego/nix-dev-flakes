{
	description = "My nix flake to help with various development environments";
	inputs = {
		nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
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

					# Only needed when we need to regenerate the completion file
					# completely

					# Install the scripts in the 'scripts' folder
					(stdenv.mkDerivation {
						name		= "vaas-helper-scripts";
						buildInputs	= with pkgs; [ bash gnumake ];
						src			= self;
						installPhase = ''
							mkdir -p $out/bin
							cp ${self}/scripts/* $out/bin/
							chmod +x $out/bin/*
						'';
					})
				];

				shellHook = ''
                    export VAAS_HOME=$(pwd)/.vaas_home
                    mkdir -p $VAAS_HOME

                    # Wrap various tools so that they see $VAAS_HOME as their
                    # home dir, and keep things out of the real home dir
                    rm -rf $VAAS_HOME/bin
                    mkdir -p $VAAS_HOME/bin
                    mkdir -p $VAAS_HOME/run
                    export PATH="$VAAS_HOME/bin:$PATH"

                    cp $(which aws) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/aws							\
							--add-flags "--profile $AWS_PROFILE"			\
							--set HOME "$VAAS_HOME"

                    cp $(which kubectl) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/kubectl --set HOME "$VAAS_HOME"

                    cp $(which k9s) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/k9s --set HOME "$VAAS_HOME"

                    cp $(which helm) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/helm --set HOME "$VAAS_HOME"

                    cp $(which docker) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/docker						\
							--set HOME "$VAAS_HOME"							\
							--set XDG_RUNTIME_DIR "$VAAS_HOME/run"			\
                            --set DOCKER_HOST "unix://$VAAS_HOME/docker.sock"

                    cp $(which dockerd) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/dockerd --set HOME "$VAAS_HOME"

                    cp $(which dockerd-rootless) $VAAS_HOME/bin/
                    wrapProgram $VAAS_HOME/bin/dockerd-rootless				\
							--set HOME "$VAAS_HOME"							\
							--set XDG_RUNTIME_DIR "$VAAS_HOME/run"			\
                            --add-flags "--data-root $VAAS_HOME/docker"		\
                            --add-flags "-H unix://$VAAS_HOME/docker.sock"	\
							--set DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SANDBOX false \
							--set DOCKERD_ROOTLESS_ROOTLESSKIT_SLIRP4NETNS_SECCOMP false

                    # Load user options, and prompt if they aren't set
					eval $(vaasdev config hook)
					if ! vaasdev config check >/dev/null ; then
						if ! vaasdev config prompt; then
							exit 0
						fi
						eval $(vaasdev config hook)
					fi

					# Setup various bits
                    vaasdev docker	setup || exit 0
                    vaasdev helm	setup || exit 0
                    vaasdev aws		setup || exit 0

					# Enable bash completion for 'vaasdev'
					source "$(dirname `which vaasdev`)/completely.bash"

                    echo ""
					echo -e "SUCCESS: \033[0;33mYour VaaS development environment is now ready.\033[0m"
                    echo ""
                    '';
			};
		}
	);
}
