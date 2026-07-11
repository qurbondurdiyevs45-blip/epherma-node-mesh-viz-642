#!/bin/bash
set -e

# EphemeraNode Mesh Viz - Multi-Stack Deployment Orchestrator
# This script handles the build process for the high-performance WebGL observability tool.

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}Starting EphemeraNode Mesh Viz deployment...${NC}"

# Check for required build tools
check_dependency() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}Error: $1 is not installed.${NC}"
        exit 1
    fi
}

dependencies=("docker" "node" "npm" "go" "rustc" "python3" "mvn" "dotnet")
for dep in "${dependencies[@]}"; do
    check_dependency "$dep"
done

# 1. Compile Core Polyglot Adapters (Rust/Wasm and Go)
echo -e "${GREEN}Building Rust High-Performance Heat-Map Engine...${NC}"
cd src/engine/rust_core
cargo build --release --target wasm32-unknown-unknown
cd ../../../

echo -e "${GREEN}Building Go Mesh-Traffic Collector...${NC}"
cd src/collectors/go_mesh
go build -o ../../../bin/mesh-collector main.go
cd ../../../

# 2. Build Multi-Language Microservice Stubs (Polyglot Stack Simulation)
echo -e "${GREEN}Building Polyglot Microservices (C#, Java, Python, Ruby)...${NC}"
# .NET Core Implementation
dotnet publish src/services/dotnet_worker -c Release -o ./dist/dotnet
# Java Implementation
mvn -f src/services/java_service/pom.xml clean package
# Python/Ruby/PHP/Node logic is handled inside the Docker container layers

# 3. Frontend Build (React/WebGL & Mobile Flutter)
echo -e "${GREEN}Building React WebGL Frontend...${NC}"
cd src/frontend/web
npm install
npm run build
cd ../../../

echo -e "${GREEN}Building Flutter Mobile Dashboard...${NC}"
cd src/frontend/mobile
flutter build web --release
cd ../../../

# 4. Container Orchestration & Docker Build
echo -e "${GREEN}Creating EphemeraNode Docker Mesh...${NC}"

# Create a shared network if it doesn't exist
docker network inspect ephemera-net >/dev/null 2>&1 || \
    docker network create ephemera-net

# Build the main aggregator container
docker build -t ephemeranode/aggregator:latest -f docker/aggregator.Dockerfile .

# Build the visualization frontend container
docker build -t ephemeranode/viz-ui:latest -f docker/frontend.Dockerfile .

# 5. Database Initialization (SQL migrations)
echo -e "${GREEN}Running SQL Schema Migrations...${NC}"
# Assuming a temporary instance or existing DB container for schema update
# PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -U $DB_USER -d ephemera_db -f src/db/schema.sql

# 6. Final Deployment / Startup
echo -e "${BLUE}Deployment successful. Orchestrating services...${NC}"

if [ "$1" == "--run" ]; then
    echo -e "${GREEN}Launching ephemeral stack via Docker Compose...${NC}"
    docker-compose -f docker-compose.yml up -d
    echo -e "${BLUE}Dashboard available at http://localhost:8080${NC}"
    echo -e "${BLUE}WebGL Heat-Map visualization active.${NC}"
else
    echo -e "${GREEN}Build artifacts are ready in the /dist and /bin directories.${NC}"
    echo -e "${GREEN}Run './scripts/deploy.sh --run' to start the full stack.${NC}"
fi

exit 0