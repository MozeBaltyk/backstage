# Backstage Vanilla

A Backstage Vanilla with:
[X] Split frontend and backend 
[X] Hardened images and unprivileged containers 
[X] Relatively small images (backend ~700MB;frontend ~200MB)
[ ] Pipeline to Build image and test images        
[ ] Renovate to auto-update and track security alerts      

For the moment, it's a Vanilla backstage which can be use to test new templates and plugins, Test backstage or plugins upgrade... 
As a prerequisites, you need a k3d cluster with the config in `./k3d/config.yaml`


## How I created this *backstage* 

* Prerequisites inside **Project** directory:
    - OS deps = `sudo apt install -y make build-essential python3 curl git`
    - NVM package manager: `curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash`
    - nodejs 24 = `nvm version-remote --lts=krypton > .nvmrc && nvm install`
    - *npm* and *npx* come with nodejs
    - yarn install and settings: `corepack enable && yarn set version stable && yarn --version`

* Create a backstage from scratch: 
    1. `npx @backstage/create-app@latest`
    2. `yarn start`

* Split Frontend and Backend following [doc](https://backstage.io/docs/deployment/docker/#separate-frontend) (already done in Vanilla)

```BASH
cd vanilla
sed '/plugin-app-backend/d' -i packages/backend/src/index.ts
sed '/plugin-app-backend/d' -i packages/backend/package.json
sed '/"app": "link:../d' -i packages/backend/package.json
yarn install
```

* Use current **Vanilla** backstage inside `cd vanilla`: 
    - `cd vanilla`
    - `yarn clean`      - Clean `dist-types` and `dist` folders
    - `yarn install`    - install dependencies
    - `yarn tsc`        - tsc outputs type definitions in `dist-types`
    - `yarn build:all`  - build *app* and *backend* in `dist`  
    - `yarn start`

* Build *frontend* and *backend* images:
    - `cd vanilla; podman build -f Containerfile.frontend -t frontend:local . --progress=plain --no-cache; cd -`
    - `cd vanilla; podman build -f Containerfile.backend  -t backend:local . --progress=plain --no-cache; cd -`
 
* Test locally images (unprivileged images)

```BASH
podman run -d \
    -u 65532 \
    --cap-drop=ALL \
    --read-only \
    --tmpfs /tmp \
    -e APP_CONFIG_backend_database_client='better-sqlite3' \
    -e APP_CONFIG_backend_database_connection=':memory:' \
    -e APP_CONFIG_auth_providers_guest_dangerouslyAllowOutsideDevelopment='true' \
    -p 7007:7007 \
    backend:local

podman run -d \
    -u 65532 \
    --cap-drop=ALL \
    -p 3000:8080 \
    frontend:local
```

* Test it on k3d (obviously k3d cluster deployed with internal registry is required ):

> [Important]
>
> Obviously k3d cluster deployed with internal registry is required here...
> Plus `localhost:5000/backstage-backend:local` and `localhost:5000/backstage-frontend:local` to be build and pushed to k3d registry.
>    
> `podman tag frontend:local localhost:5000/backstage-frontend:local && podman push localhost:5000/backstage-frontend:local`
>    
> `podman tag backend:local localhost:5000/backstage-backend:local && podman push localhost:5000/backstage-backend:local `
>   


```BASH
# Add backstage repo 
helm repo add backstage https://backstage.github.io/charts
helm repo update

# Check the manifest
helm template backstage/backstage -f helm/values-backstage.yaml -n backstage

# Deploy with helm
helm upgrade --install backstage backstage/backstage -n backstage --create-namespace  -f helm/values-backstage.yaml
```

link to front: `http://backstage.localhost:8080`

## Troubleshooting

* Check the frontend context (app-config values pass to the front):  `curl -H "Host: backstage.localhost" http://localhost:8080`



## Upgrade and update component

* From Vanilla directory: 
  - `yarn backstage-cli versions:bump` - Manual Backstage upgrade
  - `yarn install` - Then install dependencies
  - Check backstage doc if something need to be adapted in the code with:  
      * [upgrade-helper](https://backstage.github.io/upgrade-helper/?from=1.46.0&to=1.47.0&yarnPlugin=1)
  
* Or init a new backstage project:
  - `make init-backstage PROJECT_NAME=vanilla2`

* Open topic: [new frontend system](https://backstage.io/docs/frontend-system/building-apps/migrating/)...

## Dev Software Catalog

in `app-config.yaml` 

```yaml
catalog:
  locations:
    - type: url
      target: https://github.com/backstage/backstage/blob/master/packages/catalog-model/examples/components/artist-lookup-component.yaml
```

## Dev Backstage Templates 

* To test a template:
    - Via Backstage UI - In your Backstage instance, open Create… ➜ Register existing component. 
    - `npx @backstage/create-app --from https://raw.githubusercontent.com/ORG/REPO/main/templates.yaml`

* Example: 
    [piomin](https://github.com/piomin/backstage-templates)


## Handle plugins 

* Install backstage plugins

```bash
yarn --cwd packages/app add @backstage/plugin-home
yarn --cwd packages/app add @backstage-community/plugin-tech-radar
yarn --cwd packages/backend add @backstage/plugin-auth-backend-module-guest-provider
yarn --cwd packages/app add @backstage/plugin-kubernetes
yarn --cwd packages/backend add @backstage/plugin-kubernetes-backend
yarn --cwd packages/app add @backstage/plugin-kubernetes-cluster/alpha
yarn --cwd packages/backend add @headlamp-k8s/backstage-plugin-headlamp-backend
yarn --cwd packages/app add @headlamp-k8s/backstage-plugin-headlamp
```

* Create a custom new plugins: 

> Backstage is a shell. Plugins are what make it a platform.

```BASH
cd vanilla
yarn new --select frontend-plugin
yarn new --select backend-plugin

# test it
curl localhost:7007/plugin-name/health
```

## Pipeline

Renovate is used to track dependencies and opens PR:
  - [Renovate Dashboard](https://developer.mend.io/github/MozeBaltyk/backstage)

Github Workflows:
  - the CI build frontend/backend images and display the CVE on the PR.
  - Release Build and deliver the images

## Sources and References

1. Backstage app example:
    - [Piomin example](https://github.com/piomin/backstage)
    - [khuedoan example](https://github.com/khuedoan/backstage)
    - [Puziol](https://devsecops.puziol.com.br/en/idp/backstage/code)
    - [KodeKloud app](https://github.com/kodekloudhub/backstage)
    - [KodeKloud notes](https://notes.kodekloud.com/docs/Certified-Backstage-Associate-CBA/Backstage-Basics/Why-Backstage/page)

2. Plugins:
    - [Argo plugin](https://github.com/cnoe-io/plugin-argo-workflows)

3. Hardening images:
    - [Inspired by](https://medium.com/google-cloud/harden-your-containerized-backstage-app-for-kubernetes-6bcab5f0bf87)
    - [The next steps](https://itnext.io/go-distroless-with-your-backstage-app-with-docker-hardened-images-dhi-b61539ffbf00)

4. Best pratices and goals:
    - [To go in Prod](https://medium.com/@sumit.kaul.87/backstage-in-production-from-developer-portal-to-platform-operating-system-0083121c28b1)