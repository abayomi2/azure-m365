# 🚀 Enterprise DevOps & Microsoft 365 Automation Project

## 📌 Overview
This project delivers an **end-to-end DevOps + Microsoft 365 automation environment**.  
It integrates **Terraform**, **Azure DevOps**, **Azure Monitor**, and **Azure Automation Runbooks** to manage:

- Cloud-native app deployment
- Observability (monitoring, dashboards, alerts)
- Security & compliance enforcement
- Microsoft 365 onboarding (users, Teams, Intune)

---

## 🏗️ Project Phases

### Phase 1: Core Infrastructure
Provisioned with **Terraform**:
- Resource Group (`ish-dev-rg`)
- Virtual Network + Subnets
- App Service Plan (`ish-dev-api-plan`)
- Azure Container Registry (`ishdevacr01`)
- Log Analytics Workspace (`ish-dev-law`)

---

### Phase 2: App Deployment
- CI/CD Pipeline (`azure-pipelines-app.yml`) builds container images and pushes them to ACR.
- App Service (`ish-dev-api`) pulls container images from ACR using **Managed Identity**.
- Deployment slots (`staging`) configured for safe rollouts.

---

### Phase 3: Observability & Monitoring
- **Azure Monitor Diagnostic Settings** enabled for App Service & ACR.
- **Application Insights (`ish-dev-ai`)** for telemetry & performance metrics.
- **Metric Alerts**:
  - HTTP 5xx error alert (`app-http5xx-high`)
  - CPU & availability monitoring

---

### Phase 4: Security & Compliance
- App Service enforced `httpsOnly`.
- Azure Policy module (require tags, enforce HTTPS).
- ACR access restricted to MI with `AcrPull` role.
- Terraform backend state secured in Storage + DynamoDB.

---

### Phase 5: Dashboards & Alerts
- Centralized dashboard in Log Analytics Workspace.
- Email-based action groups for alerting (`ag-ops`).

---

### Phase 6: Automation & Runbooks
- **Azure Automation Account** (`ish-dev-aa`) created with Managed Identity.
- Runbooks implemented for cross-service tasks:
  - `Onboard-Users` → Bulk-create Entra ID users from CSV input.
  - `New-TeamSite` → Provision Teams/SharePoint groups.
  - `Intune-Policies` → Deploy baseline compliance/device policies.
  - `Set-UsageLocation-And-License` → Fix usage location & assign licenses.

---

## ⚙️ Phase 7: Microsoft 365 User Onboarding

### 🔹 Runbook: Onboard-Users
Automates onboarding of new users from CSV input.

**CSV Format:**
```csv
UserPrincipalName,DisplayName,GivenName,Surname,UsageLocation,LicenseSkuId,Department,JobTitle
new.user2@contoso.onmicrosoft.com,New User2,New,User2,AU,06ebc4ee-...,Engineering,Developer
new.user3@contoso.onmicrosoft.com,New User3,New,User3,,06ebc4ee-...,Finance,Analyst
new.user4@contoso.onmicrosoft.com,New User4,New,User4,AU,,Operations,Coordinator


# 🛠️ Microsoft 365 Automation Runbooks (Phase 7)

## ▶️ Run the Onboard-Users Runbook
```
CSV_CONTENT='<CSV_ABOVE>'
az automation runbook start \
  -g ish-dev-rg --automation-account-name ish-dev-aa \
  -n Onboard-Users \
  --parameters CsvContent="$CSV_CONTENT" DefaultUsageLocation="AU" DefaultLicenseSkuId="06ebc4ee-..."
```

✅ If no license seats remain → user is still created/updated, license step is skipped.

🔹 Runbook: Set-UsageLocation-And-License

Fixes existing users missing usageLocation or licenses.

UPN="new.user1@contoso.onmicrosoft.com"
SKU="06ebc4ee-..."

az automation runbook start \
  -g ish-dev-rg --automation-account-name ish-dev-aa \
  -n Set-UsageLocation-And-License \
  --parameters UserPrincipalName="$UPN" UsageLocation="AU" SkuId="$SKU"

🔐 Roles & Permissions
Terraform Service Principal

Role: Contributor on ish-dev-rg

Function: Manages infrastructure provisioning

App Service Managed Identity

Role: AcrPull on ACR

Function: Allows App Service to pull images from Azure Container Registry

Automation Account Managed Identity

Permissions on Microsoft Graph:

Directory.ReadWrite.All

Group.ReadWrite.All

DeviceManagementConfiguration.ReadWrite.All

✅ Verification
Check user status:
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/users/$UPN?\$select=userPrincipalName,usageLocation,accountEnabled,department,jobTitle" \
  -o jsonc

Check assigned licenses:
az rest --method GET \
  --url "https://graph.microsoft.com/v1.0/users/$UPN/licenseDetails" \
  --query "value[].{skuId:skuId, skuPartNumber:skuPartNumber}" -o table

📊 Example Use Case

HR provides a CSV of new hires.

Automation:

Creates accounts

Sets job roles & departments

Applies policies

Assigns licenses (if seats are available)

Teams site is provisioned for their department.

Intune policies applied automatically.

⏱️ Impact: Cuts onboarding time from hours → minutes and ensures compliance by default.

🔌 Next Workstream

The next planned phase will cover:

Scheduled automation triggers

Self-service portals

Integration with ServiceNow / HRIS for end-to-end HR-to-IT provisioning