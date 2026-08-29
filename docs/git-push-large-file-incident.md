# Incident: GitHub push rejected (large file / GH001)

## Summary

`git push origin main` failed with:

```
remote: error: File AWS_Revision_DevOps_Insider/.terraform/providers/registry.terraform.io/hashicorp/aws/6.62.0/darwin_arm64/terraform-provider-aws_v6.62.0_x5 is 784.02 MB; this exceeds GitHub's file size limit of 100.00 MB
remote: error: GH001: Large files detected. You may want to try Git Large File Storage - https://git-lfs.github.com.
 ! [remote rejected] main -> main (pre-receive hook declined)
```

## Root cause

1. `terraform init` downloaded the AWS provider binary into
   `AWS_Revision_DevOps_Insider/.terraform/providers/.../terraform-provider-aws_v6.62.0_x5` (~784 MB).
2. Commit `a8c2217` ("Add Terraform provider configurations") ran `git add` before a `.gitignore`
   existed, so the entire `.terraform/` provider cache — including that binary — got tracked by git.
3. `.gitignore` (with a `.terraform/` entry) was only added in the *next* commit (`89ca9a2`). A
   `.gitignore` rule only stops git from tracking a **new** file — it does nothing for a file that's
   already committed. So every commit after `a8c2217` still carried the 784 MB blob in its history.
4. GitHub hard-rejects any pushed object over 100 MB via its `pre-receive` hook (GH001), so the push
   failed — and it would keep failing on every future push, since git always has to send the full
   history behind the branch, not just the latest diff.

Deleting the file in a new commit (`git rm`) would **not** have fixed this — the file would still
exist in the earlier commit's history and git would still try to push that object.

## Fix applied

Checked `origin/main` first and confirmed it was still sitting at the very first commit — none of the
later commits (including the one with the binary) had ever reached GitHub. That made it safe to rewrite
local history without affecting any collaborator or already-published commit:

```bash
# Remove the .terraform/ directory from every commit in history
git filter-branch --force --index-filter \
  'git rm -r --cached --ignore-unmatch "AWS_Revision_DevOps_Insider/.terraform"' \
  --prune-empty -- --all

# Drop the old backup refs and reclaim space
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now

# Verify the blob is gone, then land the rewritten history
git rev-list --objects --all | grep terraform-provider-aws_v6.62.0_x5   # -> no output
git push origin main --force-with-lease
```

Result: `.git` shrank from carrying an 822 MB object down to ~132 KB, and the push succeeded.

`--force-with-lease` (not a bare `--force`) was used so the push would abort if the remote had changed
unexpectedly between the check and the push — it hadn't, so it went through.

## Prevention going forward

- `.gitignore` now also excludes Terraform state and override files, not just the provider cache:
  ```
  .terraform/
  *.tfstate
  *.tfstate.*
  crash.log
  override.tf
  override.tf.json
  *_override.tf
  *_override.tf.json
  ```
- Run `terraform init` **after** `.gitignore` is in place, or at minimum run `git status` before your
  first `git add` in a new Terraform directory — `.terraform/` (provider binaries) and `*.tfstate`
  (which can also contain secrets) should never show as untracked-and-about-to-be-added.
- If a large or sensitive file is ever committed by mistake, catch it **before** pushing
  (`git status`, `du -sh .git`) — cleanup is a simple `git reset`/`git rm --amend` if it hasn't been
  pushed yet, versus a full history rewrite (as done here) if it has.
