# GCP Infrastructure with Terraform + GitHub Actions
## (Interview Learning Project)

---

## Project Structure

```
gcp-terraform-project/
├── terraform/
│   ├── provider.tf      # Terraform provider + GCS backend
│   ├── variables.tf     # Input variables
│   ├── vpc.tf           # VPC, Subnet, Firewall rules
│   ├── vm.tf            # Compute VM + Service Account
│   ├── storage.tf       # Cloud Storage + Private Endpoint (PSC)
│   └── outputs.tf       # Output values
└── .github/
    └── workflows/
        └── terraform.yml  # CI/CD pipeline
```

---

## Architecture Overview

```
GitHub Actions
     │
     │ (OIDC - no keys!)
     ▼
GCP Service Account (terraform-runner)
     │
     ├── Creates VPC + Subnet (private_ip_google_access = true)
     ├── Creates VM (no public IP)
     │       │
     │       │ uses vm-service-account
     │       ▼
     │   Cloud Storage Bucket
     │       ▲
     └── PSC Endpoint (private IP 10.0.2.2)
             │
         DNS override routes storage.googleapis.com
         → private IP (never leaves Google network)
```

---

## BEFORE Running the Pipeline — IAM Setup in GCP

You need **two service accounts** and one **Workload Identity Pool**.

### Step 1 — Enable Required GCP APIs

```bash
gcloud services enable \
  compute.googleapis.com \
  storage.googleapis.com \
  dns.googleapis.com \
  iam.googleapis.com \
  iamcredentials.googleapis.com \
  cloudresourcemanager.googleapis.com
```

### Step 2 — Create the Terraform Runner Service Account

This is the identity GitHub Actions will use to run Terraform.

```bash
gcloud iam service-accounts create terraform-runner \
  --display-name="Terraform Runner (GitHub Actions)"
```

### Step 3 — Grant IAM Roles to the Terraform Runner

```bash
PROJECT_ID="your-project-id"
SA_EMAIL="terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com"

# Roles needed to create/manage our resources
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/dns.admin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountAdmin"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"
```

**Why each role?**
| Role | Why needed |
|------|-----------|
| `compute.admin` | Create VPC, subnet, firewall, VM, PSC forwarding rule |
| `storage.admin` | Create bucket, manage IAM on bucket |
| `dns.admin` | Create private DNS zone and records |
| `iam.serviceAccountAdmin` | Create vm-service-account |
| `iam.serviceAccountUser` | Attach service account to VM |

### Step 4 — Create a GCS Bucket for Terraform State

```bash
gsutil mb -l us-central1 gs://your-tfstate-bucket-name
gsutil versioning set on gs://your-tfstate-bucket-name
```

Update `provider.tf` with this bucket name.

---

## Connecting GitHub Actions to GCP (OIDC — No Keys!)

OIDC (OpenID Connect) lets GitHub prove its identity to GCP without storing a JSON key. This is the **recommended, secure approach**.

### How it works (simple explanation)

```
GitHub Actions says: "I am workflow in repo myorg/myrepo"
        │
        ▼
GCP Workload Identity asks: "Is that repo allowed?"
        │
        ▼ (yes, based on the binding we configure)
GCP issues a short-lived token → Terraform uses it
```

### Step 5 — Create Workload Identity Pool

```bash
gcloud iam workload-identity-pools create "github-pool" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --display-name="GitHub Actions Pool"
```

### Step 6 — Create OIDC Provider inside the Pool

```bash
gcloud iam workload-identity-pools providers create-oidc "github-provider" \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --display-name="GitHub Provider" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository=='YOUR-ORG/YOUR-REPO'"
```

Replace `YOUR-ORG/YOUR-REPO` with your actual GitHub repo.

### Step 7 — Allow the Pool to Impersonate the Service Account

```bash
POOL_ID=$(gcloud iam workload-identity-pools describe github-pool \
  --project="${PROJECT_ID}" \
  --location="global" \
  --format="value(name)")

gcloud iam service-accounts add-iam-policy-binding \
  "terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com" \
  --project="${PROJECT_ID}" \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/YOUR-ORG/YOUR-REPO"
```

### Step 8 — Get the Provider Resource Name

```bash
gcloud iam workload-identity-pools providers describe github-provider \
  --project="${PROJECT_ID}" \
  --location="global" \
  --workload-identity-pool="github-pool" \
  --format="value(name)"
```

Copy this output — it looks like:
`projects/123456/locations/global/workloadIdentityPools/github-pool/providers/github-provider`

---

## GitHub Secrets to Configure

In your GitHub repo → Settings → Secrets and Variables → Actions:

| Secret Name | Value |
|-------------|-------|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | The provider name from Step 8 |
| `GCP_SERVICE_ACCOUNT_EMAIL` | `terraform-runner@PROJECT_ID.iam.gserviceaccount.com` |
| `GCP_PROJECT_ID` | Your GCP project ID |
| `GCP_BUCKET_NAME` | A globally unique bucket name for your app data |

---

## Running the Pipeline

1. Push code to GitHub
2. Go to **Actions** tab → **Terraform GCP Infrastructure**
3. Click **Run workflow**
4. Choose: `plan`, `apply`, or `destroy`

**On Pull Requests** → automatically runs `plan` only (safe, no changes made)

---

## Key Interview Concepts from this Project

**Private Google Access** — Subnet setting that lets VMs without a public IP reach Google APIs (like Cloud Storage) via Google's internal network.

**Private Service Connect (PSC)** — A private endpoint inside your VPC with its own IP address. Traffic to Cloud Storage goes through this IP, never touching the internet.

**DNS Override** — We create a private DNS zone so that `storage.googleapis.com` resolves to the PSC private IP inside the VPC.

**OIDC vs Service Account Keys** — Keys are files that can be stolen. OIDC issues short-lived tokens tied to the specific GitHub repo — much safer.

**Workload Identity Federation** — The GCP mechanism that trusts GitHub's identity tokens and maps them to a service account.