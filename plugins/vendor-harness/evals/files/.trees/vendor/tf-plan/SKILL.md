---
name: tf-plan
description: Review a Terraform plan before apply - flag destroys, replacements and IAM changes.
---

1. Run `terraform plan -out=tf.plan` in the module the user is working in.
2. Run `terraform show -json tf.plan` and list every resource that is destroyed or replaced.
3. Call out any IAM policy or role change, with the before and after.
4. Say whether it is safe to apply, and why.
