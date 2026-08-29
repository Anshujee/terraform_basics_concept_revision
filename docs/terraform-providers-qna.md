# Terraform Providers — Questions & Answers

A beginner-friendly Q&A on Terraform provider concepts, explained in plain English
with real-life examples, using the real files in this project
(`AWS_Revision_DevOps_Insider/awsprovider.tf` and `Azure_revision_DevOps_Insider/provider.tf`).

---

## Table of Contents

- [Q1. What is a Provider and How Does It Work?](#q1-what-is-a-provider-and-how-does-it-work)
- [Q2. What is the Terraform Lock File and How Do I Change the Locked Version?](#q2-what-is-the-terraform-lock-file-and-how-do-i-change-the-locked-version)
- [Q3. How Do I Download Providers from a Private Artifactory or Nexus Repository?](#q3-how-do-i-download-providers-from-a-private-artifactory-or-nexus-repository)

*(Click any question above to jump straight to its answer.)*

---

## Q1. What is a Provider and How Does It Work?

> *Full question: What is a provider? Why do we use it? How does it work inside? How
> do we install one? What are the different types of providers in AWS and Azure?*

### What is a provider, in simple words?

Terraform by itself doesn't know anything about AWS, Azure, or any other cloud. All
Terraform knows how to do is one thing: read your code and manage the lifecycle of
"things" (create them, update them, delete them). It has no idea what an "EC2
instance" or an "Azure Storage Account" actually is.

A **provider** is a plugin that teaches Terraform how to talk to one specific service
— AWS, Azure, GitHub, Kubernetes, etc. It's the translator sitting between your `.tf`
code and that service's real API.

**Real-life example:** think of Terraform as a **universal TV remote**, and each
provider as the **device profile** you load onto it (Samsung TV, Sony soundbar, LG
AC). The remote doesn't know how to talk to your specific TV until you load that
TV's profile onto it. The provider is that profile — except instead of a TV, it's a
cloud.

### Why do we use a provider?

Every cloud has its own login system and its own set of building blocks — AWS calls
storage an "S3 bucket," Azure calls the same idea a "Storage Account," but the actual
API underneath is completely different. Without a provider:

- Terraform wouldn't understand what `resource "aws_instance"` means.
- Terraform wouldn't know how to log in to AWS or Azure.
- Terraform wouldn't know how to turn your code into a real action like "create this
  server" or "delete this bucket."

The provider does all of that work for you, so you just write simple code describing
*what you want*, and the provider handles *how to actually get it done*.

### How does a provider work, step by step?

1. **You write code** saying which provider you want to use:
   ```hcl
   provider "aws" {
     # Configuration option
   }
   ```

2. **Terraform checks your `required_providers` block** to know exactly which
   provider and version to grab. From this project's own
   `AWS_Revision_DevOps_Insider/awsprovider.tf`:
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
   - `source = "hashicorp/aws"` means "get the AWS provider published by HashiCorp."
   - `version = "6.62.0"` means "use exactly this version, so my code behaves the
     same way every time."

3. **Terraform downloads the provider as a real program** (not just a config file)
   and saves it in a hidden folder called `.terraform/`. This is the same kind of
   large binary file that caused this project's earlier git incident — see
   `docs/git-push-large-file-incident.md`.

4. **Every time you run `terraform plan` or `terraform apply`**, Terraform hands your
   code to that provider program, which:
   - Turns it into a real API call to AWS/Azure (using your credentials).
   - Sends it, gets a response back (e.g., "server created, here's its ID").
   - Reports that result back to Terraform, which saves it in the **state file**.

5. **Terraform never talks to AWS or Azure directly** — it always goes through the
   provider. That's why the same commands (`plan`, `apply`, `destroy`) work no matter
   which cloud you're using; only the provider changes.

**Real-life example:** it's like ordering food through a delivery app. You (Terraform)
don't cook the food or drive to the restaurant yourself — you place the order in the
app, and the delivery partner (the provider) is the one who actually goes to the
restaurant (AWS/Azure), picks it up, and brings back the result.

### How do we install a provider?

You basically never install one by hand. You just:

1. Write the `required_providers` block (shown above).
2. Run:
   ```bash
   terraform init
   ```

`terraform init` reads that block, downloads the matching provider from the Terraform
Registry, saves it in `.terraform/providers/...`, and writes a
`.terraform.lock.hcl` file recording exactly which version it downloaded (more on
that file in [Q2](#q2-what-is-the-terraform-lock-file-and-how-do-i-change-the-locked-version)).

**Beginner note:** never commit the `.terraform/` folder to git — it's a local cache
and can be huge. Only `.terraform.lock.hcl` should be committed. This project's
`.gitignore` already excludes `.terraform/` for exactly this reason.

### What are the different types of providers in AWS and Azure?

First, a quick correction of the premise: **AWS and Azure each have just ONE main
provider**, not many:

| Cloud | Provider name | Registry source |
|---|---|---|
| AWS | `aws` | `hashicorp/aws` |
| Azure | `azurerm` (Azure Resource Manager) | `hashicorp/azurerm` |

What actually varies is the **resource types** inside each provider:

**AWS (`hashicorp/aws`) — example resources:**
- `aws_instance` — a virtual machine (EC2)
- `aws_s3_bucket` — file storage
- `aws_vpc`, `aws_subnet` — networking
- `aws_iam_role` — permissions
- `aws_lambda_function` — serverless code
- `aws_rds_instance` — managed database

**Azure (`hashicorp/azurerm`) — example resources:**
- `azurerm_linux_virtual_machine` — a virtual machine
- `azurerm_storage_account` — file storage (Azure's version of S3)
- `azurerm_virtual_network`, `azurerm_subnet` — networking
- `azurerm_role_assignment` — permissions
- `azurerm_function_app` — serverless code
- `azurerm_sql_database` — managed database

**Real-life example:** think of it like ordering a coffee at Starbucks vs. Costa —
both are "coffee shop providers," but the menu items (resources) have different names
even though they do the same job (a latte is a latte either way). One provider, many
menu items inside it.

There are also a few other niche providers (`azuread` for Azure Active Directory,
`awscc` for AWS's newer Cloud Control API), but `aws` and `azurerm` — the two this
project already uses — cover 95% of everyday work.

[⬆ Back to top](#table-of-contents)

---

## Q2. What is the Terraform Lock File and How Do I Change the Locked Version?

> *Full question: What is the purpose of `.terraform.lock.hcl`, and if we've already
> locked a version, how do we change it?*

### What is `.terraform.lock.hcl` for?

When you run `terraform init`, Terraform looks at your version rule (like
`version = "6.62.0"`, or a looser rule like `version = ">= 6.0"`) and picks a
matching provider to download. A loose rule could technically resolve to a different
version on different days or different machines.

`.terraform.lock.hcl` removes that guesswork. It's Terraform's version of a
**lockfile** — the same idea as `package-lock.json` in Node.js. Once `terraform init`
runs successfully, this file records:

- The **exact version** that was downloaded.
- **Security checksums** proving the downloaded file is genuine and untampered.

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

- `version` → the exact version locked in.
- `constraints` → the version rule from your `.tf` file that produced this choice.
- `hashes` → checksums so Terraform can confirm the downloaded file hasn't been
  altered or corrupted.

**Real-life example:** imagine three teammates set up this AWS project on three
different laptops on three different days, with no lock file. Person A gets AWS
provider v6.62.0. Person B, setting up a week later, gets v6.70.0 because that's now
the latest matching version. Person B's `terraform plan` suddenly behaves
differently — maybe a resource argument got renamed in that newer version — and now
there's a confusing bug that "only happens on Person B's machine." The lock file
prevents this entirely: everyone who runs `terraform init` gets the *exact same*
version, guaranteed, until someone deliberately updates the lock file.

This is exactly why the lock file **should be committed to git** — unlike
`.terraform/` (the actual downloaded binary), which should never be committed (see
`docs/git-push-large-file-incident.md` for what happens when a huge binary like that
gets pushed by accident).

### How do we change the version once it's locked?

You can't just hand-edit `.terraform.lock.hcl` — the file itself warns "Manual edits
may be lost in future updates." Instead, change the **version rule in your `.tf`
file**, and let Terraform re-lock it for you:

**Step 1 — Update the version** in your provider block. Example, in
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
Plain `terraform init` (no flag) will **refuse** to move off the locked version — it
just reuses what's already recorded, to protect you from silent drift. `-upgrade`
tells Terraform: "yes, go find a version that matches my new rule and re-lock it."

**Step 3 —** Terraform rewrites `.terraform.lock.hcl` with the new version and new
checksums, automatically.

**Step 4 —** Commit the updated lock file to git, so your team gets the same new
version too.

**A softer alternative — version ranges:** instead of pinning an exact version, you
can allow small automatic upgrades:
```hcl
version = "~> 6.62"   # allows 6.62.x and 6.6x, but never jumps to 7.x
```
Even with a range, the lock file still pins one exact resolved version — you'd still
run `terraform init -upgrade` to move to a newer version inside that range.

**Quick summary:**

| Goal | Command |
|---|---|
| Use the version already locked (normal day-to-day use) | `terraform init` |
| Move to a new version | Change `version` in `.tf` → `terraform init -upgrade` |
| Lock file is broken/out of sync | Delete `.terraform.lock.hcl` → `terraform init` (rebuilds it) |

[⬆ Back to top](#table-of-contents)

---

## Q3. How Do I Download Providers from a Private Artifactory or Nexus Repository?

> *Full question: In a secure/enterprise project, how do we download providers from a
> private artifact repository (JFrog Artifactory, Nexus) instead of directly from the
> public internet? Step by step.*

### Why would we do this?

**Real-life example:** picture a bank's internal DevOps team. Their build servers are
locked down and can't reach the open internet at all — a security rule, not a
technical limitation. But their engineers still need Terraform providers like
`hashicorp/aws`. The fix: put an internal gateway — **JFrog Artifactory** or
**Sonatype Nexus** — in the middle. That gateway is allowed to reach the internet
(once, in a controlled way), downloads and scans the provider, and then every
engineer's laptop pulls it from that internal gateway instead:

```
Before: Your laptop/server → registry.terraform.io (public internet)
After:  Your laptop/server → Artifactory/Nexus (internal, scanned) → registry.terraform.io
```

Artifactory/Nexus fetches each provider from the public registry **once**, caches it,
and serves every future request from that cache — nothing has to touch the public
internet again.

Terraform supports this natively, without changing how you run `terraform init`.
There are three ways to wire it up, depending on how much control you need.

---

### Approach A (most common): Network Mirror — no `.tf` file changes needed

Your `.tf` files (like this project's `awsprovider.tf`) stay exactly as they are —
you still write `source = "hashicorp/aws"`. Only your local Terraform **CLI setup**
changes, so it fetches providers through your internal mirror instead of the internet.

**Step 1 — Create a "Terraform" repository in Artifactory or Nexus.**
- **JFrog Artifactory:** create a repository of type **"Terraform"** as a **remote
  repository** pointing at `https://registry.terraform.io` (it proxies and caches the
  public registry).
- **Nexus Repository (Pro):** create a **Terraform proxy repository** pointing at the
  same public registry URL.

Either tool shows you a specific base URL for this repo in its UI (often under "Set
Me Up") — copy it, you'll need it in Step 3. It typically looks like:
```
https://artifactory.yourcompany.com/artifactory/api/terraform/terraform-remote/providers/
```

**Step 2 — Create Terraform's CLI config file** (separate from your project's `.tf`
files):
- macOS/Linux: `~/.terraformrc`
- Windows: `%APPDATA%\terraform.rc`
- Or point to any file using the `TF_CLI_CONFIG_FILE` environment variable — useful
  for CI/CD pipelines.

**Step 3 — Add a `provider_installation` block** so provider downloads route through
your mirror:
```hcl
# ~/.terraformrc
provider_installation {
  network_mirror {
    url = "https://artifactory.yourcompany.com/artifactory/api/terraform/terraform-remote/providers/"
  }
}
```
From here on, `terraform init` in **any** project on this machine — including this
project's `AWS_Revision_DevOps_Insider` and `Azure_revision_DevOps_Insider` folders —
pulls `hashicorp/aws` and `hashicorp/azurerm` through Artifactory instead of the
internet, with zero edits to `awsprovider.tf` or `provider.tf`.

**Step 4 (if login is required) — add credentials:**
```hcl
credentials "artifactory.yourcompany.com" {
  token = "YOUR_ARTIFACTORY_IDENTITY_TOKEN"
}
```
Never commit this file to git — it's a personal machine setting, like
`~/.aws/credentials`, not a project file.

**Step 5 — Run Terraform as normal:**
```bash
terraform init
```
Everything else — `plan`, `apply`, the lock file (see
[Q2](#q2-what-is-the-terraform-lock-file-and-how-do-i-change-the-locked-version)) —
works exactly the same as before.

---

### Approach B: Point the provider `source` directly at your private registry

Some teams prefer to make it explicit in the code itself which registry a project
uses — useful if different projects need different internal registries. This needs
Artifactory/Nexus to support the full Terraform Provider Registry Protocol (both do).

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
Now the internal registry is baked into the code — anyone who clones this repo and
runs `terraform init` automatically pulls from Artifactory, with no CLI config file
needed (though they'll still need credentials, same as Step 4 above).

---

### Approach C: Fully offline / air-gapped — Filesystem Mirror

**Real-life example:** a defense or government project where the build server has
**zero** network access — not even to Artifactory. Providers have to be carried in
physically.

**Step 1 —** on a machine that *does* have access, run:
```bash
terraform providers mirror ./local-provider-mirror
```
This downloads everything the project needs into a properly structured local folder.

**Step 2 —** copy `./local-provider-mirror` onto the air-gapped machine (USB drive,
internal transfer — whatever your security process allows).

**Step 3 —** in `.terraformrc` on that machine:
```hcl
provider_installation {
  filesystem_mirror {
    path = "/opt/terraform/local-provider-mirror"
  }
}
```

**Step 4 —** `terraform init` now reads providers straight off local disk — no
network call at all.

---

### Which approach should you actually use?

| Situation | Use |
|---|---|
| Company has an internal gateway, machines can reach it | **Approach A** — most common, zero `.tf` changes |
| Want it explicit in code which registry a project uses | **Approach B** — custom `source` |
| Machine has zero network access at all | **Approach C** — filesystem mirror |

For this project specifically: setting up Approach A means both
`AWS_Revision_DevOps_Insider/awsprovider.tf` and `Azure_revision_DevOps_Insider/provider.tf`
would start pulling `hashicorp/aws` and `hashicorp/azurerm` through Artifactory/Nexus
the next time `terraform init -upgrade` runs — with no edits to either file.

[⬆ Back to top](#table-of-contents)

---

*(More questions will be added below as they're asked.)*
