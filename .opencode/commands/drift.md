---
description: Compare repo configs with the live dotfiles
agent: plan
---

Run `scripts/audit/drift.sh` and explain the output.

For each reported file:

- say which side is canonical (the repo is, except where `audit/changes.md` records that a live
  change has not been committed yet)
- give the exact command to reconcile it (copy repo → home, or update the repo copy)
- flag any difference that would change behaviour, as opposed to comments or whitespace

Do not edit or copy files. Report only.
