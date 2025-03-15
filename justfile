# Define variables for convenience
set dotenv-load
COMPOSE_FILE := "docker-compose.yml"
DEV_COMPOSE_FILE := "docker-compose.yml"
REPO_NAME := `basename $PWD`

# Task to bring up the docker-compose stack
default:
    @just up

#################### Devnet tasks ####################

# Bring up the devnet
devnet-up:
    sh scripts/devnet/devnet-up.sh

# Shut down all services
devnet-down:
    docker compose -f {{DEV_COMPOSE_FILE}} stop

# Rebuild the services if needed
devnet-build:
    docker compose -f {{DEV_COMPOSE_FILE}} build

# Remove volumes (for cleanup purposes)
devnet-clean:
    docker compose -f {{DEV_COMPOSE_FILE}} down -v
    docker image ls '{{REPO_NAME}}*' --format='{{ '{{.Repository}}' }}' | xargs -r docker rmi
    docker volume ls --filter name='{{REPO_NAME}}*' --format='{{ '{{.Name}}' }}' | xargs -r docker volume rm
    rm -rf envs/devnet/config/genesis/
