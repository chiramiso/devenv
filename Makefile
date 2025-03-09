# List of "primary" targets that do not refer to a project name
PRIMARY_TARGETS := build rebuild shell start stop logs test lint clean_volumes init purge setup link up down tap taplog 
NO_PROJECT_TARGETS := list-running-containers help

# Set the CODE_DIR to the parent directory. This assumes that all the projects are in the same parent directory.
CODE_DIR := $(shell dirname $(shell dirname $(abspath $(lastword $(MAKEFILE_LIST)))))

# Get the current working directory
DEVENV_PATH := $(shell pwd)

# If second argument exists and is not a primary target, use it as project name
ifeq ($(filter $(word 2,$(MAKECMDGOALS)),$(PRIMARY_TARGETS)),)
  PROJECT := $(word 2,$(MAKECMDGOALS))
  # Remove the project name from the goals so it isn't treated as a filename
  $(eval $(word 2,$(MAKECMDGOALS)):;@:)
endif

# If the target contains a hyphen, extract the project name
ifneq ($(findstring -,$(firstword $(MAKECMDGOALS))),)
  PROJECT := $(subst $(firstword $(subst -, ,$(firstword $(MAKECMDGOALS))))-,,$(firstword $(MAKECMDGOALS)))
endif

# Ensure PROJECT is set for targets that require it
ifneq ($(filter $(firstword $(MAKECMDGOALS)),$(NO_PROJECT_TARGETS)),)
  # No project needed for these targets
else ifneq ($(PROJECT),)
  PROJECT_DIR=$(DEVENV_PATH)/projects/$(PROJECT)
else
  $(error PROJECT is not set. Please provide a project name as the second argument.)
endif

# Function to read environment variables from .env file
define read_env
$(shell if [ -f $(1) ]; then grep -v '^#' $(1) | xargs -0 printf '%b\n' 2>/dev/null; fi)
endef

# Function to extract port mappings from environment variables
define get_port_mappings
$(shell if [ -f $(1) ]; then grep '_PORT=' $(1) | sed 's/.*=\(.*\)/\1:\1/'; fi)
endef

# Default docker options (adjust if needed)
DOCKER_RUN_OPTS = -v $(PROJECT_DIR):/code
ENV_FILE=$(PROJECT_DIR)/.env

# Include environment file if present
ifneq (,$(wildcard $(ENV_FILE)))
  # Read all environment variables from .env file
  ENV_VARS := $(call read_env,$(ENV_FILE))
  # Add each environment variable to docker run options
  DOCKER_RUN_OPTS += $(foreach var,$(ENV_VARS),--env $(var))
  # Get all port mappings from variables ending with _PORT
  PORT_MAPPINGS := $(call get_port_mappings,$(ENV_FILE))
  # Add each port mapping to docker run options
  DOCKER_RUN_OPTS += $(foreach port,$(PORT_MAPPINGS),-p $(port))
endif

.PHONY: $(PRIMARY_TARGETS)

### Build the images
build:
	@$(MAKE) build-$(PROJECT) --no-print-directory

build-%:
	@echo "==> Building base image for project '$*' using Dockerfile in $(PROJECT_DIR)"
	docker build -t $*-base $(PROJECT_DIR)
	@echo "==> Building dev image for project '$*' using common Dockerfile in $(DEVENV_PATH)"
	docker build --build-arg BASE_IMAGE=$*-base -t $*-dev $(PROJECT_DIR)

### Rebuild images without using cache
rebuild:
	@$(MAKE) rebuild-$(PROJECT) --no-print-directory

rebuild-%:
	@echo "==> Rebuilding base image for project '$*' with no cache"
	docker build --no-cache -t $*-base $(PROJECT_DIR)
	@echo "==> Rebuilding dev image for project '$*' with no cache"
	docker build --no-cache --build-arg BASE_IMAGE=$*-base -t $*-dev $(PROJECT_DIR)

### Run an interactive shell in the container
shell:
	@$(MAKE) shell-$(PROJECT) --no-print-directory

shell-%:
	@echo "==> Starting an interactive shell for project '$*'"
	docker run -it $(DOCKER_RUN_OPTS) $*-dev /bin/bash

### Start the container in detached mode
start:
	@$(MAKE) start-$(PROJECT) --no-print-directory

start-%:
	@echo "==> Starting container for project '$*' in detached mode"
	@if [ ! -f "$(PROJECT_DIR)/.env" ]; then \
		echo "Warning: No .env file found at $(PROJECT_DIR)/.env"; \
	fi
	docker run -d $(DOCKER_RUN_OPTS) --name $*-dev-container $*-dev bash /code/scripts/start.sh

### Stop the running container
stop:
	@$(MAKE) stop-$(PROJECT) --no-print-directory

stop-%:
	@echo "==> Stopping container for project '$*'"
	-docker exec $*-dev-container bash /code/scripts/stop.sh
	-docker stop $*-dev-container || true
	-docker rm $*-dev-container || true

### View logs from the running container
logs:
	@$(MAKE) logs-$(PROJECT) --no-print-directory

logs-%:
	@echo "==> Viewing logs for project '$*'"
	docker logs -f $*-dev-container

### Run tests inside the container
test:
	@$(MAKE) test-$(PROJECT) --no-print-directory

test-%:
	@echo "==> Running tests for project '$*'"
	docker run --rm $(DOCKER_RUN_OPTS) $*-dev bash /code/scripts/test.sh

### Run linter inside the container
lint:
	@$(MAKE) lint-$(PROJECT) --no-print-directory

lint-%:
	@echo "==> Running linter for project '$*'"
	docker run --rm $(DOCKER_RUN_OPTS) $*-dev bash /code/scripts/lint.sh

### Clean up named volumes (if used)
clean_volumes:
	@$(MAKE) clean_volumes-$(PROJECT) --no-print-directory

clean_volumes-%:
	@echo "==> Cleaning volumes for project '$*'"
	docker volume rm $*-data || true

### Purge all docker containers related to the project
purge:
	@$(MAKE) purge-$(PROJECT) --no-print-directory

purge-%:
	@echo "==> Purging all containers and images for project '$*'"
	-docker stop $*-dev-container
	-docker rm $*-dev-container
	-docker rmi $*-dev
	-docker rmi $*-base

# Create a symlink in the projects folder pointing to the specified project path
link:
	@$(MAKE) link-$(PROJECT) PATH=$(path) --no-print-directory

link-%:
	@if [ -z "$(PATH)" ]; then \
		echo "Error: Please specify the path to the project using 'path=path/to/project'"; \
		exit 1; \
	fi;
	@mkdir -p projects
	@/bin/ln -sfn $(PATH) projects/$*
	@echo "==> Linked project '$*' to $(PATH)"

# Run the link_projects.sh script to set up project symlinks
setup:
	@echo "Running project setup..."
	@bash $(pwd)/scripts/link_projects.sh

### Initialize a new project structure
init:
	@$(MAKE) init-$(PROJECT) --no-print-directory

init-%:
	@echo "==> Initializing new project structure in $(CODE_DIR)/$*"
	mkdir -p $(CODE_DIR)/$*/scripts $(CODE_DIR)/$*/source
	cp templates/Dockerfile.template $(CODE_DIR)/$*/Dockerfile
	cp templates/gitignore.template $(CODE_DIR)/$*/.gitignore
	cp templates/dockerignore.template $(CODE_DIR)/$*/.dockerignore
	echo "PORT=3000" > $(CODE_DIR)/$*/.env.example
	echo "#!/bin/bash\necho 'Starting $* application...'" > $(CODE_DIR)/$*/scripts/start.sh
	echo "#!/bin/bash\necho 'Stopping $* application...'" > $(CODE_DIR)/$*/scripts/stop.sh
	echo "#!/bin/bash\necho 'Running tests for $*...'" > $(CODE_DIR)/$*/scripts/test.sh
	echo "#!/bin/bash\necho 'Linting $* source code...'" > $(CODE_DIR)/$*/scripts/lint.sh
	chmod +x $(CODE_DIR)/$*/scripts/*.sh
	ln -sfn $(CODE_DIR)/$* projects/$*
	@echo "==> Project '$*' initialized. Customize the Dockerfile and scripts as needed."

### Run docker-compose up for a specific setup
up:
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please specify a setup name (e.g., make up setup-name)"; \
		exit 1; \
	fi
	@SETUP_NAME=$(word 2,$(MAKECMDGOALS)); \
	COMPOSE_FILE="docker-setups/$$SETUP_NAME/docker-compose.yml"; \
	if [ ! -f "$$COMPOSE_FILE" ]; then \
		echo "Error: docker-compose.yml not found at $$COMPOSE_FILE"; \
		exit 1; \
	fi; \
	echo "==> Starting docker-compose setup '$$SETUP_NAME'"; \
	docker-compose -f $$COMPOSE_FILE up -d --remove-orphans
	
### Run docker-compose down for a specific setup
down:
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please specify a setup name (e.g., make down setup-name)"; \
		exit 1; \
	fi
	@SETUP_NAME=$(word 2,$(MAKECMDGOALS)); \
	COMPOSE_FILE="docker-setups/$$SETUP_NAME/docker-compose.yml"; \
	if [ ! -f "$$COMPOSE_FILE" ]; then \
		echo "Error: docker-compose.yml not found at $$COMPOSE_FILE"; \
		exit 1; \
	fi; \
	echo "==> Stopping docker-compose setup '$$SETUP_NAME'"; \
	docker-compose -f $$COMPOSE_FILE down

### List running containers
list-running-containers:
	@echo "==> Listing all running containers across docker-compose setups"
	@find $(DEVENV_PATH)/docker-setups -type f -name "docker-compose.yml" -execdir bash -c ' \
		project_name=$$(basename "$$(pwd)"); \
		output=$$(docker compose ps --quiet --filter "status=running" 2>/dev/null); \
		if [ -n "$$output" ]; then \
			echo ""; \
			header_line=""; \
			for i in $$(seq 1 $$(expr $${#project_name} + 4)); do \
				header_line="$$header_line#"; \
			done; \
			echo "$$header_line"; \
			echo "# $$project_name #"; \
			echo "$$header_line"; \
			printf "\n"; \
			docker compose ps --filter "status=running" 2>/dev/null | grep -v "^WARN\\|^env file"; \
			printf "\n"; \
			echo "---"; \
		fi \
	' \;
	@echo ""
	@echo "==> For other containers, use 'docker ps'"

### Connect to a running container
tap:
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please specify a container name (e.g., make tap container-name)"; \
		exit 1; \
	fi
	@CONTAINER_NAME=$(word 2,$(MAKECMDGOALS)); \
	if ! docker ps --format '{{.Names}}' | grep -q "^$$CONTAINER_NAME$$"; then \
		echo "Error: Container '$$CONTAINER_NAME' is not running"; \
		exit 1; \
	fi; \
	echo "==> Connecting to container '$$CONTAINER_NAME'"; \
	docker exec -it $$CONTAINER_NAME /bin/bash || docker exec -it $$CONTAINER_NAME /bin/sh

### View logs of a running container
taplog:
	@if [ -z "$(word 2,$(MAKECMDGOALS))" ]; then \
		echo "Error: Please specify a container name (e.g., make taplog container-name)"; \
		exit 1; \
	fi
	@CONTAINER_NAME=$(word 2,$(MAKECMDGOALS)); \
	if ! docker ps --format '{{.Names}}' | grep -q "^$$CONTAINER_NAME$$"; then \
		echo "Error: Container '$$CONTAINER_NAME' is not running"; \
		exit 1; \
	fi; \
	echo "==> Viewing logs for container '$$CONTAINER_NAME'"; \
	docker logs -f $$CONTAINER_NAME

### Display help information about available make commands
help:
	@echo "Devenv - Docker-based Development Environment"
	@echo ""
	@echo "Usage: make [target] [project]"
	@echo ""
	@echo "Project Management:"
	@echo "  init [project]              Initialize a new project structure"
	@echo "  setup                       Set up project symlinks for all projects"
	@echo "  link [project] path=PATH    Create a symlink for a specific project"
	@echo ""
	@echo "Docker Image Management:"
	@echo "  build [project]             Build the project's Docker images"
	@echo "  rebuild [project]           Rebuild the project's Docker images without cache"
	@echo "  purge [project]             Purge all Docker containers and images for a project"
	@echo ""
	@echo "Container Management:"
	@echo "  start [project]             Start the project's container in detached mode"
	@echo "  stop [project]              Stop the running container for the project"
	@echo "  shell [project]             Run an interactive shell in the project's container"
	@echo "  logs [project]              View logs from the running container"
	@echo "  clean_volumes [project]     Clean up named volumes associated with the project"
	@echo ""
	@echo "Development Tasks:"
	@echo "  test [project]              Run tests inside the project's container"
	@echo "  lint [project]              Run linter inside the project's container"
	@echo ""
	@echo "Docker Compose Setups:"
	@echo "  up [setup-name]             Start all containers in a Docker Compose setup"
	@echo "  down [setup-name]           Stop and remove all containers in a Docker Compose setup"
	@echo "  list-running-containers     List all running containers across docker-compose setups"
	@echo ""
	@echo "Container Interaction:"
	@echo "  tap [container-name]        Access an interactive shell in a running container"
	@echo "  taplog [container-name]     View live logs of a running container"
	@echo ""
	@echo "Help:"
	@echo "  help                        Display this help message"

# Make catch-all rule to handle the setup name argument
%:
	@:
