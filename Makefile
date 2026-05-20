SHELL := /bin/sh
.DEFAULT_GOAL := help

ENV ?= homelab
ENV_DIR := environments/$(ENV)
LOCAL_CONFIG_ROOT ?= $(ENV_DIR)
PRIVATE_CONFIG_ROOT ?= ../platform-private/infra
CONFIG_ROOT ?= $(if $(PRIVATE),$(PRIVATE_CONFIG_ROOT),$(LOCAL_CONFIG_ROOT))
TFVARS ?= $(if $(PRIVATE),$(CONFIG_ROOT)/$(ENV).tfvars,$(CONFIG_ROOT)/terraform.tfvars)
TFVARS_EXAMPLE := $(ENV_DIR)/terraform.tfvars.example
TFVARS_ABS := $(abspath $(TFVARS))
CONFIG_ROOT_ABS := $(abspath $(CONFIG_ROOT))

PLATFORM_SSH_INIT ?= platform-ssh-init
SSH_KEY_DIR ?= $(HOME)/.ssh
SSH_KEY_PREFIX ?= platform-infra
TOFU_VERSION ?= 1.11.7
TOFU_INSTALL_DIR ?= $(HOME)/.local/bin
TOFU_BIN ?= $(TOFU_INSTALL_DIR)/tofu
TOOLS_DIR ?= .tools

.PHONY: help deps env init init-ssh fmt validate verify clean _install-tofu

## Show available commands
help:
	@printf '%s\n' 'Available targets:'
	@awk '\
		/^## / { help = substr($$0, 4); next } \
		/^[a-zA-Z0-9_.-]+:/ { \
			if (help != "") { \
				target = $$1; \
				sub(/:.*/, "", target); \
				printf "  %-24s %s\n", target, help; \
				help = ""; \
			} \
		} \
	' $(MAKEFILE_LIST) | sort
	@printf '\n%s\n' 'Variables:'
	@printf '  %-24s %s\n' 'ENV' 'Environment name, default: homelab'
	@printf '  %-24s %s\n' 'PRIVATE' 'Use ../platform-private/infra config when set, default: empty'
	@printf '  %-24s %s\n' 'CONFIG_ROOT' 'Config root, default: environments/$(ENV) or ../platform-private/infra'
	@printf '  %-24s %s\n' 'TFVARS' 'OpenTofu var file, default follows CONFIG_ROOT'
	@printf '  %-24s %s\n' 'SSH_KEY_DIR' 'Directory for generated per-VM SSH keys, default: $(HOME)/.ssh'
	@printf '  %-24s %s\n' 'SSH_KEY_PREFIX' 'Prefix for generated per-VM SSH keys, default: platform-infra'
	@printf '  %-24s %s\n' 'TOFU_VERSION' 'OpenTofu version, default: 1.11.7'
	@printf '  %-24s %s\n' 'TOFU_INSTALL_DIR' 'Directory for tofu, default: $(HOME)/.local/bin'
	@printf '  %-24s %s\n' 'TOFU_BIN' 'OpenTofu binary path, default: $(TOFU_INSTALL_DIR)/tofu'
	@printf '\n%s\n' 'Examples:'
	@printf '  %s\n' 'make deps'
	@printf '  %s\n' 'make env PRIVATE=1'
	@printf '  %s\n' 'make env ENV=dev PRIVATE=1'
	@printf '  %s\n' 'make init-ssh PRIVATE=1'
	@printf '  %s\n' 'make init-ssh ENV=dev PRIVATE=1'
	@printf '  %s\n' 'make verify TOFU_INSTALL_DIR="$$PWD/.tools/bin"'

_install-tofu:
	@TOFU_VERSION="$(TOFU_VERSION)" TOFU_INSTALL_DIR="$(TOFU_INSTALL_DIR)" sh scripts/install-opentofu.sh

## Install and check local dependencies
deps: _install-tofu

## Create tfvars from example if missing
env:
	@TFVARS="$(TFVARS)" \
	TFVARS_EXAMPLE="$(TFVARS_EXAMPLE)" \
	sh scripts/create-env-config.sh

## Initialize per-VM cloud-init SSH keys with platform-tools
init-ssh:
	@ENV="$(ENV)" \
	ENV_DIR="$(ENV_DIR)" \
	TFVARS="$(TFVARS_ABS)" \
	SSH_KEY_DIR="$(SSH_KEY_DIR)" \
	SSH_KEY_PREFIX="$(SSH_KEY_PREFIX)" \
	PLATFORM_SSH_INIT="$(PLATFORM_SSH_INIT)" \
	SSH_EMPTY_PASSPHRASE="$(SSH_EMPTY_PASSPHRASE)" \
	sh scripts/init-cloud-init-ssh.sh

## Initialize the selected OpenTofu environment
init: deps
	@cd "$(ENV_DIR)" && "$(TOFU_BIN)" init

## Format OpenTofu files
fmt: deps
	@"$(TOFU_BIN)" fmt -recursive

## Validate OpenTofu configuration
validate: init
	@cd "$(ENV_DIR)" && "$(TOFU_BIN)" validate

## Format and validate OpenTofu configuration
verify: fmt validate

## Remove repo-local tool installs
clean:
	rm -rf "$(TOOLS_DIR)"
