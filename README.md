Increment Service Hub (ISH) — DevOps Hands-On (Azure)

A portfolio-grade, end-to-end DevOps implementation on Microsoft Azure showing real-world practices for a Managed Support Services (MSS) team:

IaC with Terraform (resource groups, ACR, App Service, diagnostics, alerts)

Containers built/pushed to Azure Container Registry (ACR)

Azure Web App (Linux) with deployment slots (staging → production)

Managed Identity + AcrPull (no registry passwords)

CI/CD with Azure DevOps Pipelines (build → push → deploy → swap)

Monitoring (Log Analytics, App Insights, metrics/KQL alerts) & Security (policy guardrails, HTTPS/TLS, RBAC)

You can deploy it, demo it, and destroy it cleanly.

Table of Contents

What You Build

Repo Layout

Prerequisites

Phase 0: Bootstrap Terraform State (once)

Phase 1: Core Infra (ACR + App Service + Network)

Phase 2: Containerized App

Phase 3: CI/CD with Azure DevOps

Phase 4: Blue/Green with Deployment Slots

Phase 5: Monitoring & Alerting

Phase 6: Security & Compliance

Roles, Permissions & Why

Useful Commands

Troubleshooting

Tear Down

What You Build

RG: ish-dev-rg

ACR: ishdevacr01

App Service Plan: ish-dev-api-plan (Linux S1+ for slots)

Web App: ish-dev-api (container)

Staging slot: ish-dev-api-staging → Swap to prod

Log Analytics Workspace: ish-dev-law

Application Insights: ish-dev-ai

Diagnostic Settings: App Service & ACR → LAW

Alerts:

Metric alert: HTTP 5xx spikes (App Service metrics)

(Optional/KQL) Error rate in AI/Logs

Action Group: email notifications

Repo Layout
.
├─ app/
│  └─ api/
│     ├─ public/            # static dashboard files
│     ├─ server.js          # Node/Express + /healthz
│     ├─ package.json
│     └─ Dockerfile
├─ infra/
│  ├─ modules/
│  │  ├─ appservice/        # Service plan + Linux Web App (container)
│  │  ├─ container_registry # ACR
│  │  ├─ network/           # (optional) vnet/subnets
│  │  └─ observability/     # LAW, AI, diag settings, alerts
│  └─ envs/
│     └─ dev/
│        ├─ main.tf         # wires modules; backend configured here
│        └─ (providers.tf, variables.tf, etc.)
└─ azure-pipelines-app.yml  # CI/CD pipeline

Prerequisites

Azure subscription (Owner/Contributor level access for initial setup)

Azure CLI logged in (az login)

Terraform >= 1.5

Docker (local build)

Azure DevOps project

App Service plan S1 or better (slots not supported on B1)

Phase 0: Bootstrap Terraform State (once)

If you already configured a remote state account/container, skip this.

Create a “bootstrap” RG + Storage Account + container for Terraform state (names may vary; examples only):

RG_BOOT=rg-ish-bootstrap
LOC=australiaeast
STG=ishbootstrapstate
CNT=tfstate

az group create -n $RG_BOOT -l $LOC
az storage account create -g $RG_BOOT -n $STG -l $LOC --sku Standard_LRS
az storage container create --account-name $STG --name $CNT


In infra/envs/dev/main.tf (or a backend.tf), point the backend to the above storage.

Phase 1: Core Infra (ACR + App Service + Network)

From your dev env folder:

cd infra/envs/dev
terraform init -reconfigure
terraform apply -auto-approve


Outputs:

acr_login_server = ishdevacr01.azurecr.io

api_hostname = ish-dev-api.azurewebsites.net

This creates the RG, ACR, App Service Plan, Web App (container), network (if used), and wires Managed Identity + AcrPull so the Web App can pull images securely (no ACR creds).

Phase 2: Containerized App
Local test
cd app/api
npm install
npm start
# http://localhost:8080

Build & push manually (optional sanity)
ACR=ishdevacr01
ACR_LOGIN=ishdevacr01.azurecr.io

az acr login --name $ACR
cd app/api
docker build -t $ACR_LOGIN/ish-api:latest .
docker push $ACR_LOGIN/ish-api:latest


In real flow this is performed by the pipeline.

Phase 3: CI/CD with Azure DevOps

Create a Service Connection in Azure DevOps → svc-az-spn

Scope: Resource group ish-dev-rg

Permissions it needs: Contributor on RG, AcrPush on ACR

(Optional) User Access Administrator if you want the pipeline to create role assignments automatically.

Create Variable Group ish-dev:

ACR_NAME = ishdevacr01

ACR_LOGIN_SERVER = ishdevacr01.azurecr.io

RESOURCE_GROUP = ish-dev-rg

WEBAPP_NAME = ish-dev-api

Import pipeline (azure-pipelines-app.yml) in DevOps and run.

Pipeline stages

Preflight: validates variables

Build_Push: docker build → docker push to ACR

Deploy_Staging: creates staging slot, assigns Managed Identity, grants AcrPull, points slot to new image, warms /healthz

Approve_and_Swap: manual approve → swap staging → production → post-swap health check

Phase 4: Blue/Green with Deployment Slots

Slots require S1 or higher plan. Commands used behind the scenes:

# Create slot (first time)
az webapp deployment slot create -g ish-dev-rg -n ish-dev-api --slot staging --configuration-source ish-dev-api

# Assign MI to slot
az webapp identity assign -g ish-dev-rg -n ish-dev-api --slot staging

# Get slot MI principalId
SLOT_MI=$(az webapp identity show -g ish-dev-rg -n ish-dev-api --slot staging --query principalId -o tsv)

# Grant AcrPull to slot MI on ACR
ACR_ID=$(az acr show -n ishdevacr01 --query id -o tsv)
az role assignment create --assignee-object-id "$SLOT_MI" --role AcrPull --scope "$ACR_ID"

# Point slot to new image & restart
az webapp config container set -g ish-dev-rg -n ish-dev-api --slot staging \
  --docker-custom-image-name ishdevacr01.azurecr.io/ish-api:<tag> \
  --docker-registry-server-url https://ishdevacr01.azurecr.io
az webapp restart -g ish-dev-rg -n ish-dev-api --slot staging

# Swap staging → production
az webapp deployment slot swap -g ish-dev-rg -n ish-dev-api --slot staging --target-slot production


The pipeline automates all of this.

Phase 5: Monitoring & Alerting

Terraform module observability provisions:

Log Analytics Workspace: ish-dev-law

Application Insights: ish-dev-ai (workspace-based)

Diagnostic Settings:

App Service → LAW: AppServiceHTTPLogs, AppServiceConsoleLogs, metrics

ACR → LAW: RepositoryEvents, LoginEvents, metrics

Action Group: email receiver

Metric Alert: App Service HTTP 5xx spikes (15-minute window)

(Optional) KQL Alert: error-rate using AI/Logs (enable when telemetry exists)

Optional App Insights instrumentation for the Node app (to enable the KQL alert):

Add applicationinsights dependency

Initialize in server.js if APPLICATIONINSIGHTS_CONNECTION_STRING is set

Pass the connection string via Web App app settings (already wired in module)

Hit the app a few times → requests table appears in LAW → enable enable_kql_alert = true

Phase 6: Security & Compliance

Hardened defaults built-in:

Managed Identity pulls images from ACR (AcrPull role); no ACR passwords

App Service https_only = true

TLS 1.2 enforced via Azure Policy (optionally assign RG-level built-ins)

RBAC everywhere (no inline creds)

Diagnostic settings for auditability

Defender for Cloud (recommended to enable plans for App Service & Container Registries via Portal)

You can assign built-in Azure Policies at RG/subscription scope for:

Require HTTPS / TLS 1.2 on App Service

Require tags on resources

HTTPS-only on ACR

We used azurerm_resource_group_policy_assignment (v3 provider) to assign at RG scope (IDs vary per tenant—paste your Definition IDs).

Roles, Permissions & Why
Azure DevOps Service Connection: svc-az-spn

Contributor on ish-dev-rg

Create/update Web Apps, add slots, set app settings, restart, etc.

AcrPush on ishdevacr01

Push Docker images during CI

(Optional) User Access Administrator / Owner on ACR scope

Allows pipeline to create role assignments (grant AcrPull to slot MI).

If not granted, run the az role assignment create once manually.

Azure App Service (Linux) — Managed Identity

System-assigned identity on the Web App and staging slot

AcrPull on ACR (both prod app and staging slot)

This replaces DOCKER_* username/password settings entirely

Used implicitly when container pulls via acr_use_managed_identity_cred = true

Action Group (Monitor)

Email receiver; no extra permissions (Monitor invokes the action)

Terraform Backend (bootstrap)

Storage Account for remote state (kept outside the dev RG)

Not destroyed when you destroy the dev RG

Azure Policies (optional)

Assignments at RG/subscription scope

Enforce HTTPS/TLS1.2, required tags, etc.

Audit non-compliance in Azure Policy → Compliance

Useful Commands
Terraform
cd infra/envs/dev
terraform init -reconfigure
terraform plan
terraform apply -auto-approve
terraform destroy -auto-approve

ACR / Docker (manual checks)
az acr login --name ishdevacr01
docker build -t ishdevacr01.azurecr.io/ish-api:latest ./app/api
docker push ishdevacr01.azurecr.io/ish-api:latest

Web App / Slot
# Create slot (if not created by pipeline)
az webapp deployment slot create -g ish-dev-rg -n ish-dev-api --slot staging --configuration-source ish-dev-api

# Assign/inspect managed identity on slot
az webapp identity assign -g ish-dev-rg -n ish-dev-api --slot staging
az webapp identity show   -g ish-dev-rg -n ish-dev-api --slot staging --query principalId -o tsv

# Grant AcrPull to slot MI
ACR_ID=$(az acr show -n ishdevacr01 --query id -o tsv)
SLOT_MI=$(az webapp identity show -g ish-dev-rg -n ish-dev-api --slot staging --query principalId -o tsv)
az role assignment create --assignee-object-id "$SLOT_MI" --role AcrPull --scope "$ACR_ID"

# Swap
az webapp deployment slot swap -g ish-dev-rg -n ish-dev-api --slot staging --target-slot production

Health & Browse
https://ish-dev-api-staging.azurewebsites.net/healthz
https://ish-dev-api.azurewebsites.net/healthz
https://ish-dev-api.azurewebsites.net

Monitoring sanity
# Diagnostic settings
az monitor diagnostic-settings list --resource $(az webapp show -g ish-dev-rg -n ish-dev-api --query id -o tsv) -o table
az monitor diagnostic-settings list --resource $(az acr show -n ishdevacr01 --query id -o tsv) -o table

# Alerts
az monitor metrics alert list -g ish-dev-rg -o table

Troubleshooting

“Cannot complete, slots not allowed” → App Service Plan must be S1 or higher. Upgrade plan SKU.

Pipeline can’t create role assignment → Grant the service connection User Access Administrator or run the az role assignment create --assignee-object-id <slot_MI> --role AcrPull manually.

KQL alert fails: table 'requests' not found → Add App Insights SDK or switch the query to AppServiceHTTPLogs. Enable the KQL alert after telemetry exists.

Docker build warning about legacy builder → Install buildx locally, or ignore (Azure DevOps agents already have it).

Deprecated Terraform warnings → Use docker_image_name + acr_use_managed_identity_cred (already applied in appservice module).

Tear Down

To destroy all dev resources created by this project:

cd infra/envs/dev
terraform destroy -auto-approve


This does not delete your Terraform backend (bootstrap) Storage Account (where state is kept). Remove that separately if you truly want to wipe everything.

Next Phases

Phase 7: Microsoft 365 (Entra ID onboarding, SharePoint site provisioning, Intune policies) via Azure Automation + Managed Identity

Phase 8: WAF/Front Door, custom domains, TLS certs, private networking

Phase 9: SAST/DAST, image scanning (e.g., Defender for Cloud, Trivy)

Credits

Built for the Increment (Preferred Microsoft Partner) scenario — focusing on realistic MSS operations: secure automation, cloud platform guardrails, and reliable CI/CD.