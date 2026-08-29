# Terraform Providers — Questions & Answers

A beginner-friendly Q&A on Terraform provider concepts, explained using the real files
in this project (`AWS_Revision_DevOps_Insider/awsprovider.tf` and
`Azure_revision_DevOps_Insider/provider.tf`).

---

## Q1. What is a provider? Why do we use it? How does it work inside? How do we install one? What are the different types of providers in AWS and Azure?

### What is a provider, in simple words?

Terraform itself doesn't know anything about AWS, Azure, GCP, or any other cloud.
Terraform only understands one thing: **"write infrastructure as code, and manage its
lifecycle (create, update, delete)."** It has no built-in idea of what an "EC2 instance"
or an "Azure Storage Account" actually is.

A **provider** is a plugin that teaches Terraform how to talk to a specific service —
like AWS, Azure, GCP, GitHub, Kubernetes, Datadog, etc. It's the translator between
your `.tf` code and that service's actual API.

Think of Terraform as a **universal remote control**, and each provider as the
**specific device profile** (TV, AC, sound system) loaded into it. The remote doesn't
know how to talk to your TV by itself — it needs the TV's specific signal profile.
The provider is that profile, but for a cloud instead of a TV.

### Why do we use a provider?

Because every cloud/service has its own API, its own authentication method, and its
own set of resources (e.g., AWS has "S3 buckets", Azure has "Storage Accounts" — same
idea, completely different API underneath). Without a provider:

- Terraform wouldn't know what `resource "aws_instance"` even means.
- Terraform wouldn't know how to authenticate to AWS or Azure.
- Terraform wouldn't know how to convert your `.tf` code into real API calls
  (like `CreateInstance`, `DeleteBucket`, etc).

The provider handles **all** of that, so you can just write simple, declarative code
and let the provider do the heavy lifting of talking to the cloud.

### How does a provider work internally?

Here's the flow, step by step:

1. **You write code** describing *what* you want (a resource block), for example:
   ```hcl
   provider "aws" {
     # Configuration option
   }
   ```
   This tells Terraform: "I want to use the AWS provider for the resources below."

2. **Terraform reads your `required_providers` block** to know *which* provider and
   *which version* to use. From your own project (`AWS_Revision_DevOps_Insider/awsprovider.tf`):
   ```hcl
   terraform {
     required_providers {
       aws = {
         source  = "hashicorp/aws"
         version = "6.62.0"
       }
     }
   }
   ```
   - `source = "hashicorp/aws"` → "go get the AWS provider published by HashiCorp"
   - `version = "6.62.0"` → "specifically this version, so my code behaves consistently"

3. **Terraform downloads the provider as an executable binary** (a real program, not
   just config) from the Terraform Registry, and stores it locally in a hidden folder
   called `.terraform/`. This is exactly the 784 MB binary file we ran into trouble
   with earlier — see `docs/git-push-large-file-incident.md`. That binary is the actual
   "translator" program.

4. **At runtime, Terraform starts the provider binary as a background process** and
   talks to it over a local plugin protocol (Terraform calls this the **RPC protocol**).
   Every time you run `terraform plan` or `terraform apply`:
   - Terraform sends your resource block to the provider ("here's what the user wants").
   - The provider converts it into real HTTPS API calls to AWS/Azure (using the
     credentials it was given).
   - The cloud responds (e.g., "instance created, here's its ID").
   - The provider translates that response back into a format Terraform understands
     and stores it in the **state file**.

5. **Terraform never talks to AWS or Azure directly.** It always goes through the
   provider. This is why you can use the *same* Terraform commands (`plan`, `apply`,
   `destroy`) no matter which cloud you're working with — only the provider changes.

### How do we install a provider?

You almost never install a provider "manually." You just:

1. Declare it in a `required_providers` block (as shown above).
2. Run:
   ```bash
   terraform init
   ```

`terraform init` reads your `required_providers` block, contacts the Terraform
Registry (`registry.terraform.io`), downloads the matching provider binary for your
operating system, and stores it inside `.terraform/providers/...` in your project
folder. It also writes a `.terraform.lock.hcl` file (you already have one at
`AWS_Revision_DevOps_Insider/.terraform.lock.hcl`) which **locks the exact version and
checksum** of the provider that was downloaded, so your team always gets the identical
provider — no surprises from a newer version silently changing behavior.

Important beginner note: `.terraform/` (the downloaded binaries) should **never** be
committed to git — it's just a local cache and can be huge (hundreds of MB). Only
`.terraform.lock.hcl` should be committed, because it's small and tells everyone
*which* version to download. This project's `.gitignore` already excludes `.terraform/`
for exactly this reason.

### What are the different types of providers in AWS and Azure?

A little clarification first: **AWS and Azure are each represented by ONE main
provider**, not many separate ones:

| Cloud | Main provider name | Registry source |
|---|---|---|
| AWS | `aws` | `hashicorp/aws` |
| Azure | `azurerm` (Azure Resource Manager) | `hashicorp/azurerm` |

But each of those single providers exposes **many different resource types**
underneath it — this is probably what "different types of providers" is really
pointing at. Here's the breakdown:

**AWS (`hashicorp/aws` provider) — example resource types it gives you access to:**
- `aws_instance` — EC2 virtual machines
- `aws_s3_bucket` — S3 storage buckets
- `aws_vpc`, `aws_subnet` — networking
- `aws_iam_role`, `aws_iam_policy` — permissions/identity
- `aws_lambda_function` — serverless functions
- `aws_rds_instance` — managed databases

**Azure (`hashicorp/azurerm` provider) — example resource types it gives you access to:**
- `azurerm_linux_virtual_machine` / `azurerm_windows_virtual_machine` — VMs
- `azurerm_storage_account` — storage (Azure's version of S3)
- `azurerm_virtual_network`, `azurerm_subnet` — networking
- `azurerm_role_assignment` — permissions/identity
- `azurerm_function_app` — serverless functions
- `azurerm_sql_database` — managed databases

So: **one provider per cloud, many resource types inside that provider.** There are
also *other* Azure/AWS-related providers for specific purposes (e.g., `azuread` for
Azure Active Directory, `awscc` — AWS's newer Cloud Control provider) but for general
infrastructure, `aws` and `azurerm` are the ones you'll use 95% of the time, and they're
exactly the two this project already uses.

---

*(More questions will be added below as they're asked.)*
