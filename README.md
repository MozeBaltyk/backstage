# Backstage Vanilla

A Backstage Vanilla with:
- Pipeline to Build image
- Split frontend and backend
- Hardened images and unprivileged containers
- Renovate to auto-update and track security alerts

For the moment, it's a Vanilla backstage which can be use to test new templates and plugins. 

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
sed '/plugin-app-backend/d' -i packages/backend/src/index.ts
sed '/plugin-app-backend/d' -i packages/backend/package.json
sed '/"app": "link:../d' -i packages/backend/package.json
yarn install
```

* Use current **Vanilla** backstage inside `cd vanilla`: 
    1. `cd vanilla`
    2. `yarn clean`      - Clean `dist-types` and `dist` folders
    3. `yarn install`    - install dependencies
    4. `yarn tsc`        - tsc outputs type definitions in `dist-types`
    5. `yarn build:all`  - build *app* and *backend* in `dist`  
    6. `yarn start`

* Build *frontend* and *backend* images:
    1. `podman build -f Containerfile.frontend -t frontend:local . --progress=plain --no-cache`
    2. `podman build -f Containerfile.backend  -t backend:local . --progress=plain --no-cache`
 
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


## Upgrade and update component

* From Vanilla directory: 
  - `yarn backstage-cli versions:bump` - Manual Backstage upgrade
  - `yarn install` - Then install dependencies
  - Check backstage doc if something need to be adapted in the code. 

* Or init a new backstage project:
  - `make init-backstage PROJECT_NAME=vanilla2`

## Dev Backstage Templates 

* To test a template:
    1. Via Backstage UI - In your Backstage instance, open Create… ➜ Register existing component. 
    2. `npx @backstage/create-app --from https://raw.githubusercontent.com/ORG/REPO/main/templates.yaml`

* Example: 
    [piomin](https://github.com/piomin/backstage-templates)

## Pipeline

Renovate is used to track dependencies and opens PR:
  - [Renovate Dashboard](https://developer.mend.io/github/MozeBaltyk/backstage)

Then the CI build frontend/backend images on PR and compare with Main and display the CVE in the PR.


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
