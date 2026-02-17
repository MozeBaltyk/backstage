# Disable all the default make stuff
MAKEFLAGS += --no-builtin-rules
.SUFFIXES:

## Display a list of the documented make targets
.PHONY: help
help:
	@echo Documented Make targets:
	@perl -e 'undef $$/; while (<>) { while ($$_ =~ /## (.*?)(?:\n# .*)*\n.PHONY:\s+(\S+).*/mg) { printf "\033[36m%-30s\033[0m %s\n", $$2, $$1 } }' $(MAKEFILE_LIST) | sort

.PHONY: .FORCE
.FORCE:

BACKEND_WORKLOAD_NAME = backend
BACKEND_CONTAINER_NAME = backend
BACKEND_CONTAINER_IMAGE = ${BACKEND_CONTAINER_NAME}:local
FRONTEND_WORKLOAD_NAME = frontend
FRONTEND_CONTAINER_NAME = frontend
FRONTEND_CONTAINER_IMAGE = ${FRONTEND_CONTAINER_NAME}:local


## Split the frontend from the backend.
.PHONY: split-frontend-from-backend
split-frontend-from-backend:
ifndef PROJECT_DIR
	$(error PROJECT_DIR is not set. Usage: make split-frontend-from-backend PROJECT_DIR=your-app)
endif
	sed '/plugin-app-backend/d' -i $(PROJECT_DIR)/packages/backend/src/index.ts
	sed '/plugin-app-backend/d' -i $(PROJECT_DIR)/packages/backend/package.json
	sed '/"app": "link:../d' -i $(PROJECT_DIR)/packages/backend/package.json
	yarn install

## Usage: make init-backstage PROJECT_NAME=my-app
.PHONY: init-backstage remove-frontend-from-backend remove-better-sqlite3
init-backstage:
ifndef PROJECT_NAME
	$(error PROJECT_NAME is not set. Usage: make init-backstage PROJECT_NAME=your-app)
endif
	@echo "Creating Backstage app: $(PROJECT_NAME)"
	@echo $(PROJECT_NAME) | npx @backstage/create-app@latest
	@$(MAKE) split-frontend-from-backend PROJECT_DIR=$(PROJECT_NAME)
	@cp -r ./common/container-config ./$(PROJECT_NAME)/container-config
	@cp -r ./common/.dockerignore ./$(PROJECT_NAME)/.
	@cp -r ./common/Containerfile.* ./$(PROJECT_NAME)/.
	@echo "Backstage app $(PROJECT_NAME) initialized successfully."

## Build backstage frontend and backend images
.PHONY: build-frontend-backend-images
build-frontend-backend-images:
	@echo "Building frontend image..."
	cd vanilla && podman build -f Containerfile.frontend -t frontend:local . --progress=plain --no-cache
	@echo "Building backend image..."
	cd vanilla && podman build -f Containerfile.backend -t backend:local . --progress=plain --no-cache
	@echo "Checking if local registry is available..."
	@if curl -s http://localhost:5000/v2/_catalog > /dev/null 2>&1; then \
		echo "Registry detected. Tagging and pushing images..."; \
		podman tag frontend:local localhost:5000/backstage-frontend:local; \
		podman push localhost:5000/backstage-frontend:local; \
		podman tag backend:local localhost:5000/backstage-backend:local; \
		podman push localhost:5000/backstage-backend:local; \
	else \
		echo "Local registry not available. Skipping push."; \
	fi

## k3d - Create cluster.
.PHONY: k3d-create-cluster
k3d-create-cluster:
	podman network create k3d || true
	podman network inspect k3d -f '{{ .DNSEnabled }}' || true
	k3d registry create mycluster-registry --default-network k3d --port 5000 || true
	k3d cluster create --config k3d/config.yaml --registry-config k3d/registry.yaml

## k3d - Delete cluster.
.PHONY: k3d-delete-cluster
k3d-delete-cluster:
	k3d cluster delete --config k3d/config.yaml
	k3d registry delete k3d-mycluster-registry
	podman network rm k3d

## k3d - Deploy Backstage to cluster.
.PHONY: k3d-deploy-backstage
k3d-deploy-backstage:
	helm upgrade --install backstage backstage/backstage -n backstage --create-namespace  -f helm/values-backstage.yaml

## k3d - Uninstall Backstage from cluster.
.PHONY: k3d-uninstall-backstage
k3d-uninstall-backstage:
	helm uninstall backstage -n backstage

## k3d - Test the deployment by port-forwarding the frontend service and curling it.
.PHONY: k3d-test-deployment
k3d-test-deployment:
	kubectl port-forward service/frontend 8080:8080 &
	sleep 5
	curl http://localhost:8080
