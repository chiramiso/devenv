# Set BASE_IMAGE to debian:latest by default, but can be overridden
# by passing --build-arg BASE_IMAGE=<image> to the `docker build` command
ARG BASE_IMAGE=debian:latest
FROM ${BASE_IMAGE}

# Install common development tools (adjust as needed)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      vim \
      tmux \
      git \
      jq \
      curl && \
    rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container to the mounted code
WORKDIR /code

# (Optional) set a default command (e.g. bash)
CMD ["/bin/bash"]
