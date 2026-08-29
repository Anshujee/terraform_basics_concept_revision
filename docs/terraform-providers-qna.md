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

## Q2. What is the purpose of `.terraform.lock.hcl`? And if we've already locked a version, how do we change it?

### What is `.terraform.lock.hcl` for?

When you run `terraform init`, Terraform looks at your `required_providers` block and
downloads a matching provider. But version constraints like `version = "6.62.0"` (exact)
or `version = ">= 6.0"` (range) can still leave room for ambiguity across different
machines or different days — a range could resolve to a different version each time
someone runs `init`.

`.terraform.lock.hcl` removes that ambiguity. It's Terraform's version of a
**"lockfile"** — the same idea as `package-lock.json` in Node.js or `Gemfile.lock` in
Ruby. Once `terraform init` runs successfully, it writes down:

- The **exact provider version** that was actually downloaded.
- **Cryptographic hashes** of that provider's binary, for every supported OS/platform.

Here's the real one from this project, `AWS_Revision_DevOps_Insider/.terraform.lock.hcl`:

```hcl
provider "registry.terraform.io/hashicorp/aws" {
  version     = "6.62.0"
  constraints = "6.62.0"
  hashes = [
    "h1:nWSI/kgPk9aieiY01TEKOGXRX3+L889GSkEq0SMCL6E=",
    "zh:35a9e4bc6fd622c5a99561b882025f2745f1256bbf1a8da8d6b39319b75ae0b5",
    ...
  ]
}
```

- `version` → the exact version that was downloaded and locked.
- `constraints` → the version rule from your `.tf` file that led to this choice.
- `hashes` → checksums Terraform uses to verify the downloaded binary hasn't been
  tampered with or corrupted, on every platform it might run on (Mac, Linux, Windows).

**Why this matters:** without the lock file, two people on the same team (or you today
vs. you in six months) could run `terraform init` and silently get *different* provider
versions — and a provider version bump can change behavior or even break your
`.tf` code. The lock file guarantees everyone gets the **exact same provider binary**,
every time, until someone deliberately changes it.

This is why the lock file **should be committed to git** (unlike `.terraform/`, the
actual downloaded binary folder, which should stay out of git — see
[[project_git_history_incident]] for what happens when a huge binary like that
accidentally gets committed).

### How do we change the version once it's locked?

You're not stuck with the locked version forever — you just can't change it by editing
`.terraform.lock.hcl` by hand (note the file's own warning: "Manual edits may be lost in
future updates"). Instead, change the **source of truth**, which is the `version`
constraint in your `.tf` file, then let Terraform re-resolve and re-lock it:

**Step 1 — Update the version constraint** in your provider block. For example, in
`AWS_Revision_DevOps_Insider/awsprovider.tf`:
```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"   # change this to the version you want, e.g. "6.70.0"
    }
  }
}
```

**Step 2 — Re-run init with the upgrade flag:**
```bash
terraform init -upgrade
```
Plain `terraform init` (without `-upgrade`) will actually **refuse to change** the
locked version if one is already recorded — it just reuses what's in the lock file, to
protect you from accidental drift. `-upgrade` explicitly tells Terraform: "yes, I know,
go find a version that satisfies my new constraint and re-lock it."

**Step 3 — Terraform rewrites `.terraform.lock.hcl`** with the new version and new
hashes automatically.

**Step 4 — Commit the updated lock file** to git, so your team gets the same new
version too.

**A safer middle ground — version ranges:** instead of pinning an exact version like
`"6.62.0"`, you can use a range so minor/patch upgrades are allowed without editing the
`.tf` file each time, e.g.:
```hcl
version = "~> 6.62"   # allows 6.62.x and 6.6x, but not 7.x
```
Even with a range, the lock file still pins one specific resolved version — you'd still
need `terraform init -upgrade` to move to a newer one within that range once it's locked.

**Quick summary:**
| Goal | Command |
|---|---|
| Get the exact locked version (normal use) | `terraform init` |
| Change to a new version | Edit `version` in `.tf` → `terraform init -upgrade` |
| Lock file gets out of sync somehow | Delete `.terraform.lock.hcl` → `terraform init` (regenerates it fresh) |

---

## Q3. In a secure/enterprise project, how do we download providers from a private artifact repository (JFrog Artifactory, Nexus) instead of directly from the public internet? Step by step.

### Why would we do this?

In a locked-down company environment, servers often **can't reach the public internet**
at all (no access to `registry.terraform.io`), or the security team wants **every
package that enters the company — including Terraform providers — to pass through one
controlled, scanned, audited gateway** first. That gateway is usually an artifact
repository manager like **JFrog Artifactory** or **Sonatype Nexus**.

So instead of:
```
Your laptop/server → registry.terraform.io (public internet)
```
you want:
```
Your laptop/server → Artifactory/Nexus (internal, scanned, audited) → registry.terraform.io
```
Artifactory/Nexus sits in the middle: it fetches the provider from the public registry
**once**, caches it internally, scans it, and every future request is served from that
internal cache — nothing has to touch the public internet again.

Terraform supports this out of the box, without changing how `terraform init` is used.
There are two different ways to wire it up — pick based on how much control you need.

---

### Approach A (most common): Provider "network mirror" via CLI config — no `.tf` changes needed

This is the standard approach and the one most companies use, because your `.tf` files
(like this project's `awsprovider.tf`) **don't need to change at all** — you keep writing
`source = "hashicorp/aws"` exactly as you do today. You just tell the Terraform **CLI**
(not the code) to fetch providers through your internal mirror instead of the internet.

**Step 1 — Set up a "Terraform" repository in Artifactory or Nexus.**
Both tools have a dedicated repository type for this:
- **JFrog Artifactory:** create a repository of package type **"Terraform"**, as a
  **remote repository** pointing at `https://registry.terraform.io` (it proxies and
  caches the public registry). Optionally wrap it in a **virtual repository** if you
  also want to publish your own internally-built providers alongside the proxied ones.
- **Nexus Repository (Pro):** create a **Terraform proxy repository** pointing at
  `https://registry.terraform.io`, the same idea.

Either tool will give you a specific base URL for this repo in its UI (usually under
something like "Set Me Up") — copy that URL, you'll need it in Step 3. It typically
looks like:
```
https://artifactory.yourcompany.com/artifactory/api/terraform/terraform-remote/providers/
```

**Step 2 — Create (or edit) Terraform's CLI configuration file.** This is a file
completely separate from your project's `.tf` files:
- macOS/Linux: `~/.terraformrc`
- Windows: `%APPDATA%\terraform.rc`
- or point Terraform at any custom path with the `TF_CLI_CONFIG_FILE` environment
  variable — handy for CI/CD pipelines.

**Step 3 — Add a `provider_installation` block** telling Terraform to route provider
downloads through your mirror:
```hcl
# ~/.terraformrc
provider_installation {
  network_mirror {
    url = "https://artifactory.yourcompany.com/artifactory/api/terraform/terraform-remote/providers/"
  }
}
```
From this point on, `terraform init` in **any** project on this machine — including
this project's `AWS_Revision_DevOps_Insider` and `Azure_revision_DevOps_Insider`
folders — will fetch `hashicorp/aws` and `hashicorp/azurerm` through Artifactory
instead of `registry.terraform.io`, with zero changes to `awsprovider.tf` or
`provider.tf`.

**Step 4 (if the repo requires login) — add credentials.** Most internal registries
require an API token/identity token:
```hcl
credentials "artifactory.yourcompany.com" {
  token = "YOUR_ARTIFACTORY_IDENTITY_TOKEN"
}
```
(Never commit this file to git — it's a personal machine config, like `~/.aws/credentials`,
not a project file. Keep it out of this repo entirely.)

**Step 5 — Run `terraform init` as usual** in the project:
```bash
terraform init
```
Terraform silently talks to Artifactory/Nexus instead of the internet. Nothing else
about your workflow changes — `plan`, `apply`, `.terraform.lock.hcl` (see Q2 above)
all work exactly the same.

---

### Approach B: Point the provider `source` directly at your private registry

Some teams instead change the provider `source` address itself, so it's explicit in
code that this project only ever pulls from the internal registry — useful when
different projects need different registries. This requires Artifactory/Nexus to
support the full **Terraform Provider Registry Protocol** (both do, via their
Terraform repository feature), not just plain file hosting.

In `AWS_Revision_DevOps_Insider/awsprovider.tf`, instead of:
```hcl
aws = {
  source  = "hashicorp/aws"
  version = "6.62.0"
}
```
you'd write:
```hcl
aws = {
  source  = "artifactory.yourcompany.com/hashicorp/aws"
  version = "6.62.0"
}
```
Now the `source` hostname itself *is* your internal registry — every engineer who
clones this repo and runs `terraform init` automatically pulls from Artifactory, with
no CLI config file needed on their machine (though they'll still need credentials —
Step 4 above, or a `credentials_helper` for SSO-based tokens).

---

### Approach C: Fully offline / air-gapped — filesystem mirror

If the machine running Terraform has **no network path at all** to Artifactory/Nexus
either (fully air-gapped build server), you can pre-download providers into a local
folder and point Terraform at that folder instead:

**Step 1 —** on a machine that *does* have access (e.g. one that can reach
Artifactory), run:
```bash
terraform providers mirror ./local-provider-mirror
```
This downloads every provider your current project needs into a correctly-structured
local directory.

**Step 2 —** copy that `./local-provider-mirror` folder onto the air-gapped machine
(via USB, internal file transfer, whatever your security process allows).

**Step 3 —** in `.terraformrc` on the air-gapped machine:
```hcl
provider_installation {
  filesystem_mirror {
    path = "/opt/terraform/local-provider-mirror"
  }
}
```

**Step 4 —** `terraform init` now reads providers straight off local disk — no network
call at all.

---

### Which approach should you actually use?

| Situation | Use |
|---|---|
| Company has an internal artifact gateway, machines can reach it | **Approach A** (network mirror) — most common, zero `.tf` changes |
| Want it explicit in code which registry a project uses | **Approach B** (custom `source`) |
| Machine has zero network access at all | **Approach C** (filesystem mirror) |

For this project specifically, if you set up Approach A, both
`AWS_Revision_DevOps_Insider/awsprovider.tf` and `Azure_revision_DevOps_Insider/provider.tf`
would start pulling `hashicorp/aws` and `hashicorp/azurerm` through Artifactory/Nexus
automatically the next time `terraform init -upgrade` (see Q2) is run — with no edits
to either file.

---

*(More questions will be added below as they're asked.)*
