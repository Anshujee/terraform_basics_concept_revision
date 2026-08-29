# Terraform Providers — Questions & Answers

A beginner-friendly Q&A on Terraform provider concepts, explained in plain English
with real-life examples, using the real files in this project
(`AWS_Revision_DevOps_Insider/awsprovider.tf` and `Azure_revision_DevOps_Insider/provider.tf`).

---

## Table of Contents

- [Q1. What is a Provider and How Does It Work?](#q1-what-is-a-provider-and-how-does-it-work)
- [Q2. What is the Terraform Lock File and How Do I Change the Locked Version?](#q2-what-is-the-terraform-lock-file-and-how-do-i-change-the-locked-version)
- [Q3. How Do I Download Providers from a Private Artifactory or Nexus Repository?](#q3-how-do-i-download-providers-from-a-private-artifactory-or-nexus-repository)
- [Q4. What Are the Different Blocks in Terraform (terraform, provider, resource...)?](#q4-what-are-the-different-blocks-in-terraform-terraform-provider-resource)
- [Q5. What Is RTO and RPO, and What Would They Be for This Project?](#q5-what-is-rto-and-rpo-and-what-would-they-be-for-this-project)

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

## Q4. What Are the Different Blocks in Terraform (terraform, provider, resource...)?

> *Full question: What are the different blocks in Terraform, like a resource block,
> a terraform block, a provider block?*

### The short answer

A Terraform `.tf` file is built out of **blocks** — each block is a chunk of code
wrapped in `{ }` that tells Terraform to do one specific job. You've already seen two
of them in this project's own files. Here's `AWS_Revision_DevOps_Insider/awsprovider.tf`
in full:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"
    }
  }
}

provider "aws" {
  # Configuration option
}
```

That's a `terraform` block and a `provider` block — two of Terraform's built-in block
types. There's no `resource` block in this project yet (it hasn't created any actual
AWS/Azure resource so far), so we'll walk through what one would look like too.

**Real-life example:** think of a `.tf` file like a **recipe card**. The
`terraform` block is the "kitchen setup" section (which oven, which tools you need).
The `provider` block is "which grocery store you're buying ingredients from" (AWS vs.
Azure). The `resource` block is the actual **dish you're cooking** — the thing you
end up with when the recipe is followed.

### 1. The `terraform` block — settings for Terraform itself

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

This block doesn't create anything in AWS or Azure — it configures **Terraform's own
behavior** for this project: which providers it needs and which versions
(`required_providers`, covered in [Q1](#q1-what-is-a-provider-and-how-does-it-work)),
optionally which Terraform version is required, and where to store the state file
(a `backend` block can live in here too, though this project doesn't use one yet — it
uses local state by default).

**Real-life example:** it's like the settings page of an app — it doesn't do the
app's actual job, it just configures how the app is allowed to run.

### 2. The `provider` block — configuration for one specific provider

```hcl
provider "aws" {
  # Configuration option
}
```

This block configures **how Terraform should connect to a specific service** — which
region to use, which credentials/profile to use, and so on. The word right after
`provider` (`"aws"` here) says which provider this configuration is for. This
project's block is currently empty (just a comment placeholder), which works because
the AWS provider can also pick up credentials from your AWS CLI config or environment
variables. In a real project you'd often see something like:

```hcl
provider "aws" {
  region  = "us-east-1"
  profile = "my-aws-cli-profile"
}
```

**Real-life example:** it's like entering your delivery address and payment method
into a shopping app before you order anything — it doesn't buy anything by itself,
it just sets up *how* your orders (resources) will be placed.

### 3. The `resource` block — the actual thing you want created

This is the block that does the real work — it tells Terraform "go create this thing
in the cloud." Neither `.tf` file in this project has one yet, but here's what adding
an S3 bucket to `AWS_Revision_DevOps_Insider/` would look like:

```hcl
resource "aws_s3_bucket" "my_first_bucket" {
  bucket = "devops-insider-example-bucket"
}
```

Breaking down the syntax:
- `resource` → keyword saying "I want Terraform to manage a real object."
- `"aws_s3_bucket"` → the **resource type** (comes from the `aws` provider — this is
  one of the resource types listed under Q1).
- `"my_first_bucket"` → a **name you choose**, used only inside your Terraform code
  to refer to this specific bucket later (e.g. in outputs or other resources) — it's
  not the bucket's real-world name.
- Inside `{ }` → the actual settings for that resource (here, `bucket` sets its real
  AWS name).

Run `terraform apply` with a block like this, and Terraform actually creates that S3
bucket in your AWS account — this is the block that turns code into real
infrastructure.

**Real-life example:** if the `provider` block is "which store you're shopping at,"
the `resource` block is the **actual item in your cart** — the thing that gets
delivered to your door (created in the cloud) when you check out (`terraform apply`).

### Quick comparison table

| Block | What it does | Does it create real infrastructure? | Example from this project |
|---|---|---|---|
| `terraform` | Configures Terraform itself (required providers, versions, backend) | No | `AWS_Revision_DevOps_Insider/awsprovider.tf` lines 1–8 |
| `provider` | Configures connection details for one specific provider (region, credentials) | No | `AWS_Revision_DevOps_Insider/awsprovider.tf` lines 10–12 |
| `resource` | Creates/manages one real object in the cloud (a VM, a bucket, a database...) | **Yes** | Not yet used in this project — example above |

### Bonus: other common block types you'll run into soon

Since the question opened with "like resource, terraform, provider" (implying there
are more), here are the other block types you'll meet very early in any real
Terraform project:

- **`variable`** — defines an input your `.tf` code accepts, so you don't hard-code
  values (e.g. `variable "region" { default = "us-east-1" }`).
- **`output`** — prints a value after `apply` finishes, e.g. the new resource's ID or
  URL, so you (or another script) can use it.
- **`data`** — reads information about something that **already exists** (created
  outside Terraform, or by another Terraform run) without managing/creating it.
- **`module`** — reuses a packaged group of blocks (a mini Terraform project someone
  else wrote) instead of writing everything from scratch.

**Real-life example, all together:** a `variable` is an ingredient amount you can
adjust on the recipe card ("servings: 4"); a `resource` is the dish itself; an
`output` is what you tell your guest about the finished dish ("here's the address to
pick it up from," i.e. an IP address); a `data` block is checking what's already in
your fridge before cooking; a `module` is using someone else's pre-written recipe
card instead of writing your own from scratch.

[⬆ Back to top](#table-of-contents)

---

## Q5. What Is RTO and RPO, and What Would They Be for This Project?

> *Full question: What is the concept of RTO and RPO in IT? Also explain what the RTO
> and RPO are in your project.*

### What are RTO and RPO, in simple words?

These are two numbers every team defines *before* a disaster happens, so everyone
agrees in advance on "how bad is too bad" — instead of arguing about it while
something is actually on fire.

- **RTO (Recovery Time Objective)** — **how long can we be down?** The maximum
  acceptable time between "the system went down" and "the system is back up and
  usable again."
- **RPO (Recovery Point Objective)** — **how much data can we afford to lose?**
  Measured in time, not bytes — it's "how far back in time" your last good backup is
  allowed to be when disaster strikes.

**Real-life example:** think about your phone's photo backup.
- If your phone backs up to the cloud **every night at 2 AM**, and it gets stolen at
  6 PM, you lose everything you photographed that day — your **RPO is 24 hours**
  (the gap between backups).
- If it takes you **3 days** to get a new phone, restore the backup, and be back to
  normal, your **RTO is 3 days** (how long you were "down").

If instead your photos synced continuously (every few seconds) and you could restore
onto a new phone in 10 minutes, your RPO would be near-zero and your RTO would be 10
minutes — much better, but usually more expensive/complex to achieve.

### RTO vs RPO — the picture

```
        RPO (data loss window)         RTO (downtime window)
        |<--------------------->|      |<-------------------->|
--------●------------------------●------●------------------------●-------
   last good                 DISASTER  recovery              fully back
    backup                   happens    starts                 to normal
```

- **RPO looks backward** in time from the disaster — "how much did we just lose?"
- **RTO looks forward** in time from the disaster — "how long until we're okay again?"

**Real-life example:**
- A **bank's core transaction system** needs an RPO close to **zero** (losing even one
  completed money transfer is unacceptable) and an RTO of **minutes** (people need
  their money now) — this needs expensive, highly redundant infrastructure.
- A **personal blog** could tolerate an RPO of a **day** (losing today's unpublished
  draft is annoying, not catastrophic) and an RTO of a **few hours** — a single daily
  backup and a slow manual restore is perfectly fine.

The lower you want RTO/RPO to be, the more infrastructure, automation, and money it
costs — so these numbers are a **business decision**, not just a technical one.

### What are RTO and RPO in *this* project?

Honest answer: this repo (`AWS_Revision_DevOps_Insider/` and
`Azure_revision_DevOps_Insider/`) is a **learning/practice project** — as of now it
only has `terraform` and `provider` blocks (see
[Q4](#q4-what-are-the-different-blocks-in-terraform-terraform-provider-resource)), no
actual `resource` blocks creating real, running infrastructure or storing real data.
So there's no formal RTO/RPO target here yet — those only make sense once something
real is actually running and someone depends on it staying up.

That said, here's how RTO/RPO *would* apply the moment this project starts creating
real resources, and how Terraform specifically changes the story:

**How Terraform helps RTO (downtime):**
Because everything is defined as code, this project's RTO is mostly driven by *"how
long does `terraform apply` take to rebuild"* rather than *"how long does a human take
to manually recreate 20 resources by clicking around in the AWS console."* If AWS's
`us-east-1` region had an outage, you could point `awsprovider.tf` at another region
and run `terraform apply` to stand the whole environment back up elsewhere — Terraform
turns "rebuild infrastructure" into a repeatable, fast, scripted step instead of a
slow manual one. That's the core DR value of Infrastructure as Code.

**How Terraform affects RPO (data loss):**
Terraform itself doesn't back up your *data* — it only manages *infrastructure
definitions*. If this project later added something stateful, like:
```hcl
resource "aws_db_instance" "example" {
  # ...
  backup_retention_period = 7   # keeps 7 days of automated backups
}
```
then the RPO would be determined by settings like `backup_retention_period` (for RDS)
or S3 bucket **versioning**/cross-region replication — these have to be explicitly
configured in the `.tf` code, they don't happen automatically.

**One real DR risk already worth flagging in this project:** right now, neither
`AWS_Revision_DevOps_Insider/` nor `Azure_revision_DevOps_Insider/` has a `backend`
block inside its `terraform { }` block — so the Terraform **state file** (the record
of what's actually deployed) is only stored locally on disk, not in a remote,
versioned location like an S3 bucket. If that laptop were lost, so is the record of
what infrastructure exists — which would badly hurt both RTO (harder to know what to
rebuild) and RPO (no backup of the state itself). Using a remote backend with
versioning is a standard fix, and worth its own future question if you'd like.

**Quick summary:**

| Term | Question it answers | Example target |
|---|---|---|
| RTO | How long can we be down? | "Back up within 4 hours" |
| RPO | How much data can we lose? | "Never lose more than 15 minutes of data" |
| This project today | No real resources deployed yet | No formal target — see above for what it *would* need |

[⬆ Back to top](#table-of-contents)

---

*(More questions will be added below as they're asked.)*
