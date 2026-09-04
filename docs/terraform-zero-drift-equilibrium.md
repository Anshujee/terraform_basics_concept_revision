# Zero Drift & Equilibrium in Terraform

A beginner-friendly explanation of "drift," "zero drift," and "equilibrium" in
Terraform, in plain English with real-life examples, connected back to
[`docs/terraform-providers-qna.md`](terraform-providers-qna.md) (see Q6 there for the
full breakdown of `plan`/`apply`/`refresh`).

---

## The three worlds, again

Just like in [Q6 of the Q&A doc](terraform-providers-qna.md#q6-what-do-terraform-plan-terraform-apply-and-terraform-refresh-do--and-how-do-they-affect-the-state-file),
everything here comes down to three things that are supposed to agree with each other:

| World | What it is |
|---|---|
| **Your code** (`.tf` files) | What you *want* — the desired world |
| **The state file** (`terraform.tfstate`) | What Terraform *thinks* exists — its memory |
| **Real AWS/Azure** | What *actually* exists — reality |

**Equilibrium** is simply the state where all three of these agree, perfectly, with
nothing left to change. **Drift** is what happens the moment any one of them
disagrees with the other two.

## What is "drift," exactly?

Drift = **reality quietly moved away from what your code and state file say it
should be**, usually because something changed *outside* Terraform.

**Real-life example:** you're a property manager (same analogy as Q6). Your
blueprint (code) and your notebook (state file) both say "this house has blue
walls." One day your business partner walks in and repaints a room red — without
telling you, without updating any paperwork. Now:

- Blueprint says: blue
- Notebook says: blue
- Actual house says: **red**

That gap between "what the notebook/blueprint say" and "what's actually there" is
**drift**.

### How drift actually happens in practice

- Someone logs into the AWS/Azure **console** and manually changes a setting
  (resizes an EC2 instance, changes a security group rule).
- An **automated process outside Terraform** modifies something (an auto-scaling
  event, a Lambda that "fixes" something at 2 AM).
- Another team's **separate Terraform run** touches the same resource.
- A resource is deleted **manually**, but Terraform's notebook still thinks it
  exists.
- A cloud provider makes a **default value change** on its side that your code
  never pinned down.

## What is "zero drift"?

**Zero drift** is the goal state where, at any given moment, running
`terraform plan` produces **no changes at all** — Terraform looks at your code,
looks at its notebook, looks at reality, and says: *"Nothing to do. Everything
already matches."*

```
No drift  →  terraform plan  →  "No changes. Your infrastructure matches the
                                  configuration."
```

This is the same thing as saying the system is **at equilibrium** — code, state,
and reality are all in sync, and nothing is quietly out of place waiting to
surprise you.

**Real-life example:** think of a thermostat set to 21°C. When the room is
actually 21°C, the thermostat does nothing — it's "at equilibrium" with its
target. The moment the room drifts to 19°C (someone opened a window), the
thermostat notices the gap and acts to close it. Terraform's `plan`/`apply` loop
plays the same role for your infrastructure: it constantly measures the gap
between "target" (code) and "actual" (reality), and `apply` is the action that
closes that gap.

## Why drift is dangerous, not just untidy

- **False confidence:** your code *looks* like the source of truth, but if drift
  has happened, it no longer accurately describes reality — anyone reading the
  `.tf` files is reading a lie.
- **Surprise `apply` results:** the next time someone runs `terraform apply` for an
  unrelated change, Terraform may "correct" the drifted resource too —
  potentially reverting a manual fix that was made for a good reason (e.g., an
  emergency scaling change during an incident), causing an unexpected outage.
- **Security risk:** a manually-added firewall rule or IAM permission that
  bypassed Terraform also bypassed any code review or policy check your team
  normally enforces.
- **Debugging pain:** "it works on the console but the code doesn't show it" is a
  classic, time-wasting source of confusion for the next engineer.

## How do you get to (and stay at) zero drift?

### 1. Detect drift regularly

```bash
terraform plan -refresh-only
```

This compares reality against the state file and shows you *only* what drifted,
without touching code, state, or real infrastructure. Run this on a schedule
(e.g., a nightly CI job) so drift is caught within hours, not discovered by
accident weeks later.

### 2. Correct drift deliberately, not by accident

Once you see drift, you have two honest choices — pick one, don't just run a
blind `apply`:

| Situation | What it means | What to do |
|---|---|---|
| The manual change was a **mistake** | Reality should match code | `terraform apply` — this reverts reality back to what code says |
| The manual change was **intentional/necessary** | Code is now out of date | Update the `.tf` file to match reality, so code becomes the new source of truth again |

**Property manager version:** if your partner's red paint was accidental
vandalism, you repaint it blue (`apply`). If it turns out red was actually a
good call (matches the new couch), you update the blueprint to say "red" instead
— either way, you make code and reality agree again, deliberately.

### 3. Prevent drift from happening in the first place

- **Restrict console access.** Use IAM policies so most engineers *can't*
  manually change resources that Terraform manages — all changes must go
  through a pull request and `terraform apply`.
- **Use a remote, locked state backend.** A local state file (like this
  project's `AWS_Revision_DevOps_Insider/` and `Azure_revision_DevOps_Insider/`
  currently use — see Q5 in the Q&A doc) can't be safely shared or locked. A
  remote backend (S3 + DynamoDB lock table, Azure Storage + blob lease, or
  Terraform Cloud) prevents two people from applying at the same time and
  becoming a *source* of drift themselves.
- **Run `apply` only through CI/CD**, never from individual laptops, so there's
  one single, auditable path for every change.
- **Policy as code** (e.g., HashiCorp Sentinel, Open Policy Agent) can block a
  manual or ad-hoc change from ever being approved in the pipeline in the first
  place.
- **Pin exact provider/resource versions and avoid "computed" ambiguity** where
  possible, so the provider itself isn't a source of unexpected drift between
  runs (this connects to the lock file discussion in
  [Q2](terraform-providers-qna.md#q2-what-is-the-terraform-lock-file-and-how-do-i-change-the-locked-version)).

## Zero drift vs. eventual consistency — a quick distinction

Don't confuse "zero drift" with the cloud concept of *eventual consistency*
(where an API might take a few seconds to reflect a change you just made).
Zero drift is about **who is allowed to change infrastructure and whether the
code still describes it truthfully** — a governance and process concept, not a
timing/networking one.

## Connects to this project

Right now, `AWS_Revision_DevOps_Insider/` and `Azure_revision_DevOps_Insider/`
use **local state files** with no CI/CD pipeline enforcing that all changes go
through Terraform — meaning nothing today would stop drift from happening
silently (e.g., someone editing an EC2 instance in the AWS console by hand).
Practically, the cheapest first step toward zero drift here would be running
`terraform plan -refresh-only` periodically to confirm no drift has occurred,
and eventually moving to a remote backend + CI-only `apply` policy as this
project grows past the learning stage.

## One-line summary to memorize

**Drift = reality quietly disagreeing with your code. Zero drift (equilibrium) =
code, state, and reality all agreeing, with `terraform plan` reporting no
changes. Getting there is a one-time fix; staying there is a process — regular
`-refresh-only` checks, restricted console access, and CI-only applies.**
