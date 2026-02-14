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


## Remove the frontend from the backend.
.PHONY: remove-frontend-from-backend
remove-frontend-from-backend:
	sed '/plugin-app-backend/d' -i packages/backend/src/index.ts
	sed '/plugin-app-backend/d' -i packages/backend/package.json
	sed '/"app": "link:../d' -i packages/backend/package.json
	yarn install

## Remove better-sqlite3 from backend.
.PHONY: remove-better-sqlite3
remove-better-sqlite3:
	sed '/sqlite-dev/d' -i Dockerfile
	sed '/better-sqlite3/d' -i packages/backend/package.json
	yarn install

## k3d - Create cluster.
.PHONY: k3d-create-cluster
k3d-create-cluster:
	k3d cluster create backstage --agents 1 --port '80:80'

## k3d - Delete cluster.
.PHONY: k3d-delete-cluster
k3d-delete-cluster:
	k3d cluster delete backstage

## k3d - Deploy Backstage to cluster.
.PHONY: k3d-deploy-backstage
k3d-deploy-backstage:
	kubectl apply -f k8s/backend-deployment.yaml
	kubectl apply -f k8s/backend-service.yaml
	kubectl apply -f k8s/frontend-deployment.yaml

## k3d - Test the deployment by port-forwarding the frontend service and curling it.
.PHONY: k3d-test-deployment
k3d-test-deployment:
	kubectl port-forward service/frontend 80:80 &
	sleep 5
	curl http://localhost:80