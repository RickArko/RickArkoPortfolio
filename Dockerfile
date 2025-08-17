FROM ubuntu:latest

# Download updates and install python3 and required packages
RUN apt update && apt install -y \
    python3 \
    python3-pip \
    software-properties-common \
    curl \
    ca-certificates

# Install uv and add to PATH
RUN curl -Ls https://astral.sh/uv/install.sh | bash
ENV PATH="/root/.local/bin:$PATH"

# Declaring working directory in our container
WORKDIR /opt/portfolio/

# Copy project configuration files first (for better caching)
COPY pyproject.toml uv.lock ./

# Install dependencies with uv
RUN uv sync

# Copy the rest of the application
COPY deployment ./deployment
COPY src ./src

# Change working directory to src for proper module imports
WORKDIR /opt/portfolio/src

# Expose Port and Run Application
EXPOSE 8080
CMD ["uv", "run", "gunicorn", "-w", "4", "-b", "0.0.0.0:8080", "app:app"]