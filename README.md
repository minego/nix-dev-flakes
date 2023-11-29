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

3. Install a few dependencies that are needed to start:
```
	nix-shell -i direnv nix-direnv
```

4. Add the flakes that you'd like to your source tree. This is done by adding
a reference to this repo for each flake that you would like to include in your
development environment.

The following example will enable all the build tools needed for VaaS go
service development, and all of the tools needed to deploy to a VaaS devstack,
including AWS CLI, docker (rootless and isolated), k8s, etc.

Each flake references a specific git revision, so your environment will stay
exactly the same until you update the revision.

```
	mkdir -p ~src/vaas
	cd ~/src/vaas

	echo 'use flake "github:minego/nix-dev-flakes/c0223e38160c68a1cdc7b2e635bf0d148189d867?dir=go"'   >  .envrc
	echo 'use flake "github:minego/nix-dev-flakes/c0223e38160c68a1cdc7b2e635bf0d148189d867?dir=vaas"' >> .envrc

	direnv allow
```




