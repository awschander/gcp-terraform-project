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
     │ (JSON Key stored as GitHub Secret)
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

## BEFORE Running the Pipeline — Setup in GCP

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

### Step 2 — Set your Project ID variable

```bash
PROJECT_ID="project-with-cka"
```

### Step 3 — Create the Terraform Runner Service Account

This is the identity GitHub Actions will use to run Terraform.

```bash
gcloud iam service-accounts create terraform-runner \
  --display-name="Terraform Runner (GitHub Actions)" \
  --project=$PROJECT_ID
```

### Step 4 — Grant IAM Roles to the Terraform Runner

```bash
SA_EMAIL="terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com"

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

### Step 5 — Create and Download the JSON Key

```bash
gcloud iam service-accounts keys create terraform-key.json \
  --iam-account=terraform-runner@${PROJECT_ID}.iam.gserviceaccount.com
```

View the key content and copy it:
```bash
cat terraform-key.json
```

> ⚠️ Do NOT commit this file to GitHub. Add `terraform-key.json` to `.gitignore`

### Step 6 — Create a GCS Bucket for Terraform State

This bucket stores your `terraform.tfstate` file remotely.

```bash
# Create the bucket
gcloud storage buckets create gs://project-with-cka-tfstate-bucket-name \
  --project=$PROJECT_ID \
  --location=us-central1

# Enable versioning (lets you recover old state files)
gsutil versioning set on gs://project-with-cka-tfstate-bucket-name

# Verify versioning is enabled
gsutil versioning get gs://project-with-cka-tfstate-bucket-name
```

### Step 7 — Update provider.tf with the bucket name

Open `terraform/provider.tf` and set the bucket name — **no `gs://` prefix!**

```hcl
backend "gcs" {
  bucket = "project-with-cka-tfstate-bucket-name"   # ← correct ✅
  prefix = "terraform/state"
}
```

❌ Common mistake — do NOT include `gs://`:
```hcl
bucket = "gs://project-with-cka-tfstate-bucket-name"   # ← WRONG, causes terraform init error
```

---

## Connecting GitHub Actions to GCP (JSON Key approach)

### Step 8 — Add GitHub Secrets

Go to: GitHub Repo → **Settings** → **Secrets and Variables** → **Actions** → **New repository secret**

Add these 3 secrets:

| Secret Name | Value | How to get it |
|-------------|-------|---------------|
| `GCP_CREDENTIALS` | Entire content of `terraform-key.json` | `cat terraform-key.json` |
| `GCP_PROJECT_ID` | `project-with-cka` | Your GCP project ID |
| `GCP_BUCKET_NAME` | `project-with-cka-tfstate-bucket-name` | Bucket you created above |

### Step 9 — GitHub Actions Auth Step (already in terraform.yml)

```yaml
- name: Authenticate to Google Cloud
  uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_CREDENTIALS }}
```

That's it — no OIDC setup needed with this approach.

---

## Running the Pipeline

1. Push your code to GitHub
2. Go to **Actions** tab → **Terraform GCP Infrastructure**
3. Click **Run workflow**
4. Choose your action:

| Action | What it does |
|--------|-------------|
| `plan` | Shows what Terraform WILL create — no changes made (safe) |
| `apply` | Actually creates the infrastructure in GCP |
| `destroy` | Deletes all created infrastructure |

**On Pull Requests** → automatically runs `plan` only (no changes made)

---

## Full Order of Execution

```
1. gcloud services enable ...              ← enable APIs (once only)
2. Create terraform-runner SA              ← the identity Terraform uses
3. Grant 5 IAM roles to SA                ← permissions to create resources
4. Create + download JSON key             ← how GitHub Actions authenticates
5. Create tfstate GCS bucket              ← remote state storage
6. Update provider.tf bucket name         ← no gs:// prefix!
7. Add 3 secrets to GitHub                ← GCP_CREDENTIALS, PROJECT_ID, BUCKET_NAME
8. Push code → run pipeline               ← plan first, then apply
```

---

## Clean Up After Learning

Delete the JSON key when done practicing:

```bash
# List all keys for the service account
gcloud iam service-accounts keys list \
  --iam-account=terraform-runner@project-with-cka.iam.gserviceaccount.com

# Delete using the KEY_ID from above output
gcloud iam service-accounts keys delete KEY_ID \
  --iam-account=terraform-runner@project-with-cka.iam.gserviceaccount.com
```

Destroy infrastructure to avoid GCP charges:
```bash
terraform destroy \
  -var="project_id=project-with-cka" \
  -var="bucket_name=project-with-cka-tfstate-bucket-name"
```

---

## JSON Key vs OIDC — Know this for interviews!

| | JSON Key (what we used) | OIDC / Workload Identity |
|---|---|---|
| Setup difficulty | ✅ Simple | ❌ More steps |
| Security | ⚠️ Key can be leaked | ✅ No key exists |
| Key expiry | ❌ Never expires unless rotated | ✅ Auto expires (1 hour) |
| Good for learning | ✅ Yes | ✅ Yes but complex |
| Recommended for Production | ❌ No | ✅ Yes |

**Interview answer:**
> *"For learning I used the JSON key approach for simplicity. In production I would
> use OIDC Workload Identity Federation because it eliminates long-lived credentials
> and removes the risk of key leakage."*

---

## Key Concepts for Interview

**Private Google Access** — A subnet setting that lets VMs without a public IP
reach Google APIs (like Cloud Storage) privately via Google's internal network.

**Private Service Connect (PSC)** — Creates a private endpoint inside your VPC
with its own IP address. Traffic to Cloud Storage goes through this IP,
never touching the public internet.

**DNS Override** — A private DNS zone so that `storage.googleapis.com` resolves
to the PSC private IP inside the VPC instead of the public IP.

**GCS Backend** — Stores `terraform.tfstate` remotely in Cloud Storage so that
multiple team members and CI/CD pipelines share the same state file.

**Service Account** — A non-human GCP identity used by applications (like the VM
or GitHub Actions) to authenticate and perform actions in GCP.

**terraform init** — Initialises Terraform, downloads providers, and connects to
the remote backend. Must be run before plan or apply.
