# VaaS Development Environment Nix Flakes

## What is nix and what is a flake?

[nixos.org](https://nixos.org/)

Nix is a lot of things, but the bit that is relevant for us is that a Nix flake
can be used to easily make all the dependencies needed for a developer
environment automatically.

## Setup

1. [https://nixos.org/download](Install nix) on your host OS (Any Linux distro, macOS or WSL in windows)

2. Enable some needed nix options:
```
	mkdir -p .config/nix/
	echo "extra-experimental-features = nix-command flakes" > .config/nix/nix.conf 
```

3. Install a few dependencies, such as [https://direnv.net/](direnv) that are
needed to start. This example assumes bash.
```
	nix-shell -i direnv nix-direnv
	echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
	exec bash
```

4. Add the flakes that you'd like to your source tree. This is done by adding
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
	mkdir -p ~src/vaas
	cd ~/src/vaas

	echo 'use flake "github:minego/nix-dev-flakes/e68be88?dir=go"'   >  .envrc
	echo 'use flake "github:minego/nix-dev-flakes/e68be88?dir=vaas"' >> .envrc

	direnv allow
```

5. Wait for the setup to complete, and answer each question as prompted. Once
complete you should be able to build services, deploy to a devstack, run
kubectl commands, etc.

The environment is reset when you leave the directory that contains the .envrc
file, and is setup again when you enter it again.


