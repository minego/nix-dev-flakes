# VaaS Development Environment Nix Flakes

## What is nix and what is a flake?

[nixos.org](https://nixos.org/)

Nix is a lot of things, but the bit that is relevant for us is that a Nix flake
can be used to easily make all the dependencies needed for a developer
environment automatically.

## Setup

1. Install the 'uidmap' package on your host Linux distro. This is needed to
use rootless docker, and is the only Linux dependency that can't currently be
installed automatically using nix.

2. If you are running on macOS then rootless docker does not work. You must
install and configure docker desktop before hand.

3. [Install nix](https://nixos.org/download) on your host OS (Any Linux distro, macOS or WSL in windows)

4. Enable some needed nix options:
```
	mkdir -p .config/nix/
	echo "extra-experimental-features = nix-command flakes" > .config/nix/nix.conf 
```

5. Install a few dependencies, such as [https://direnv.net/](direnv) that are
needed to start. This example assumes bash.
```
	nix-env -i direnv nix-direnv
	echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
	exec bash
```

6. Add the flakes that you'd like to your source tree. This is done by adding
a reference to this repo for each flake that you would like to include in your
development environment.

The following example will enable all the build tools needed for VaaS go
service development, and all of the tools needed to deploy to a VaaS devstack,
including AWS CLI, docker (rootless and isolated), k8s, etc.

You may included additional flakes as well for things such as installing your
preferred editor, etc.

Each flake references a specific git revision, so your environment will stay
exactly the same until you update the revision. The revision may be omitted if
you'd like the latest.

```
	mkdir -p ~/src/vaas
	cd ~/src/vaas

	echo 'use flake "github:minego/nix-dev-flakes/e50b4ef?dir=go"'   >  .envrc
	echo 'use flake "github:minego/nix-dev-flakes/e50b4ef?dir=vaas"' >> .envrc

	direnv allow
```

7. Wait for the setup to complete, and answer each question as prompted. Once
complete you should be able to build services, deploy to a devstack, run
kubectl commands, etc.

The environment is reset when you leave the directory that contains the .envrc
file, and is setup again when you enter it again.


