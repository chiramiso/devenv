# Devenv: Flexible Development Environment with Docker and Makefiles

## Overview

**Devenv** is a flexible, Docker-based development environment that allows you to manage multiple programming projects without installing languages or tools directly on your machine. Each project has its own Dockerfile for specific dependencies while sharing a common development container for tools like Vim, Tmux, and Git. A centralized Makefile streamlines commands for building, running, and managing projects.

## Directory Structure

```
~/Code/
  ├─ devenv/
  |    ├─ projects/          # Contains symlinks to the projects
  |    ├─ scripts/           # Common scripts
  |    ├─ templates/         # Templates for new projects
  │    ├─ Dockerfile         # Common development container
  │    └─ Makefile           # Controls building & running
  ├─ new-app/                   # Example project
       ├─ Dockerfile         # Project-specific Dockerfile
       ├─ Makefile           # Project-specific Makefile (optional)
       ├─ .env               # Environment variables
       ├─ .env.example       # Example env file
       ├─ .gitignore         # Git ignore rules
       ├─ scripts/           # Scripts for start/stop/test/lint
       │    ├─ start.sh
       │    ├─ stop.sh
       │    ├─ test.sh
       │    └─ lint.sh
       └─ source/            # Project source code
```

## Getting Started

### 1. Initialize a New Project

Create a new project structure with all necessary files and folders:

```bash
make init new-app
```

This creates the following structure in `~/Code/new-app/`, including starter scripts and Dockerfile.

### 2. Set Up Project Symlinks

Run the setup script to create symlinks for all or some projects in the parent directory:

```bash
make setup
```

### 3. Build the Project

Build the project’s base and development Docker images:

```bash
make build new-app
```

### 4. Run the Project

Start the container in detached mode, optionally specifying a custom port:

```bash
make start new-app
# or specify a port
make start new-app PORT=8080
```

### 5. Access an Interactive Shell

Get a shell inside the development container for the project:

```bash
make shell new-app
```

### 6. Run Tests & Linting

Run the test and linter scripts defined in `scripts/test.sh` and `scripts/lint.sh`:

```bash
make test new-app
make lint new-app
```

### 7. View Logs

Follow logs from the running container:

```bash
make logs new-app
```

### 8. Stop the Project

Stop the running container gracefully using the project’s `scripts/stop.sh` script:

```bash
make stop new-app
```

### 9. Clean Up Volumes

Remove Docker volumes associated with the project (if any are used for persistent data):

```bash
make clean_volumes new-app
```

### 10. Purge the Project

Purge all Docker containers and images related to the project:

```bash
make purge new-app
```

---

## Environment Configuration

- **.env:** Define environment-specific variables in this file. It will be automatically loaded when running the container.
- **.env.example:** Template for the `.env` file, useful for sharing environment configurations without exposing sensitive data.

---

## Customization

### Adding Dependencies

Modify the project-specific `Dockerfile` to install language-specific dependencies. For example, in `~/Code/new-app/Dockerfile`:

```dockerfile
FROM node:18

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
```

### Modifying Start/Stop/Test Scripts

Customize `scripts/start.sh`, `scripts/stop.sh`, `scripts/test.sh`, and `scripts/lint.sh` to define how your project starts, stops, runs tests, or lints code.

Example `start.sh` for a Node.js app:

```bash
#!/bin/bash
npm start
```

---

## Advanced Usage

### Override Ports

You can override the default port (3000) when starting the container:

```bash
make start new-app PORT=5000
```

### Rebuild Without Cache

To rebuild the Docker images without using the cache:

```bash
make rebuild new-app
```

### Add Global Tools

To add global tools like Vim, Tmux, or Git to all projects, modify the `~/Code/devenv/Dockerfile`.

Example:

```dockerfile
ARG BASE_IMAGE=debian:latest
FROM ${BASE_IMAGE}

RUN apt-get update && \
    apt-get install -y vim tmux git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /code
CMD ["/bin/bash"]
```

---

## Limitations

### Make Target Naming

- Make targets cannot contain hyphens. Use underscores or other naming conventions to avoid issues.

---

## Makefile Targets

### Primary Targets

- **build**: Build the project's Docker images.
- **rebuild**: Rebuild the project's Docker images without using the cache.
- **shell**: Run an interactive shell in the project's container.
- **start**: Start the project's container in detached mode.
- **stop**: Stop the running container for the project.
- **logs**: View logs from the running container.
- **test**: Run tests inside the project's container.
- **lint**: Run linter inside the project's container.
- **clean_volumes**: Clean up named volumes associated with the project.
- **init**: Initialize a new project structure.
- **purge**: Purge all Docker containers and images related to the project.
- **setup**: Set up project symlinks.

### Project-Specific Targets

- **build-%**: Build the base and development Docker images for a specific project.
- **rebuild-%**: Rebuild the base and development Docker images for a specific project without using the cache.
- **shell-%**: Start an interactive shell for a specific project.
- **start-%**: Start the container for a specific project in detached mode.
- **stop-%**: Stop the running container for a specific project.
- **logs-%**: View logs for a specific project's container.
- **test-%**: Run tests for a specific project.
- **lint-%**: Run linter for a specific project.
- **clean_volumes-%**: Clean volumes for a specific project.
- **purge-%**: Purge all containers and images for a specific project.
- **init-%**: Initialize a new project structure for a specific project.

---

## Troubleshooting

- **Environment Variables Not Loaded:** Ensure `.env` exists in the project directory and is properly formatted.
- **Container Fails to Start:** Check the logs using `make logs <project>` to diagnose issues.
- **Permission Issues on Scripts:** Make sure your scripts are executable: `chmod +x scripts/*.sh`

---

## License

MIT License

---

Happy hacking! 🚀

