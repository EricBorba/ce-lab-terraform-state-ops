# Lab M4.04 – State Management Operations
**Student:** Eric Rodrigues Borba

---

## Operations Practiced

### 1. Environment Setup & Initial Apply

Provisioned three S3 buckets (`managed`, `example1`, `example2`) using `terraform apply -auto-approve`. Verified that Terraform created the resources and tracked them in local state.

**Screenshot:** `screenshots/terraformApplying.png`

---

### 2. State Inspection

Explored state using multiple inspection commands:

- `terraform state list` — listed all three resources tracked in state (`aws_s3_bucket.managed`, `aws_s3_bucket.example1`, `aws_s3_bucket.example2`)
- `terraform state show aws_s3_bucket.managed` — inspected the full attribute set of the managed bucket, including ARN, region, tags, grants, and encryption configuration
- `terraform show -json | jq '.'` — viewed the full state as structured JSON, confirming all resource metadata including hosted zone IDs and provider details

**Screenshots:** `screenshots/exploringStateCommands.png`, `screenshots/showingJson.png`

---

### 3. Creating a Resource Outside Terraform

Created an S3 bucket (`eric-borba-state-ops-unmanaged`) directly via the AWS CLI, bypassing Terraform:

```bash
aws s3api create-bucket \
  --bucket eric-borba-state-ops-unmanaged \
  --region us-east-1

aws s3api put-bucket-tagging \
  --bucket eric-borba-state-ops-unmanaged \
  --tagging 'TagSet=[{Key=Name,Value=Unmanaged Bucket}]'

aws s3 ls | grep state-ops-unmanaged
```

Confirmed the bucket existed in AWS but was unknown to Terraform's state.

**Screenshot:** `screenshots/creatingResourceOutsideTerraform.png`

---

### 4. Importing an Existing Resource

Added the `aws_s3_bucket.imported` resource block to `main.tf`, then imported the manually created bucket into state:

```bash
terraform import aws_s3_bucket.imported eric-borba-state-ops-unmanaged
```

Import was successful. Running `terraform plan` afterwards confirmed that Terraform detected a tag drift between the real resource (tagged `"Unmanaged Bucket"`) and the desired configuration (tagged `"Imported Bucket"`), and planned an in-place update — no destroy/recreate required.

**Screenshot:** `screenshots/importingUnmanagedExistingResource.png`

---

### 5. Handling State Drift

Simulated drift by manually modifying tags on `eric-borba-state-ops-example1` via AWS CLI (adding `Manual = "Change"` and changing `Name` to `"Modified Outside"`). Running `terraform plan` detected the drift and showed `~ update in-place`. Applied the configuration to reconcile state with the desired values:

```bash
terraform apply -auto-approve
```

Terraform reverted both `example1` and `imported` to their configured tag values. Result: 0 added, 2 changed, 0 destroyed.

**Screenshot:** `screenshots/CheckingIfConfigurationMatches.png`

---

### 6. Moving Resources in State

Renamed the resource in `main.tf` from `aws_s3_bucket.example1` to `aws_s3_bucket.primary` using `sed`, and simultaneously updated the bucket name. Used `terraform state mv` to move the resource address in state to match the new name, preventing unnecessary destruction:

```bash
sed -i 's/example1/primary/g' main.tf
terraform state mv aws_s3_bucket.example1 aws_s3_bucket.primary
```

The subsequent plan showed a replacement was needed because the bucket name itself also changed (S3 bucket names are immutable), confirming that `state mv` handles address renaming, but actual property changes still trigger resource replacement.

**Screenshot:** `screenshots/movingResourcesinState.png`

---

### 7. Removing a Resource from State

Removed `aws_s3_bucket.example2` from Terraform state without destroying the actual AWS resource:

```bash
terraform state rm aws_s3_bucket.example2
```

Verified the outcome:
- `terraform state list | grep example2` — returned nothing (removed from state)
- `aws s3 ls | grep state-ops-example2` — bucket still exists in AWS (`eric-borba-state-ops-example2`)
- `terraform plan | grep example2` — Terraform now plans to *create* it again (treats it as unmanaged)

**Screenshot:** `screenshots/removingResourceFromState.png`

---

### 8. Pull and Push State

Pulled the current state to a local backup file and inspected it with `jq`:

```bash
terraform state pull > state-backup.json
cat state-backup.json | jq '.resources'
```

Confirmed the JSON structure included all tracked resources with their provider metadata, instance attributes, and schema versions. The `state-backup.json` file is committed to the repository for reference.

> **Warning:** `terraform state push` can overwrite remote state and should never be used in production without extreme care.

**Screenshot:** `screenshots/PullandPushState.png`

---

### 9. Replacing a Resource

Forced recreation of `aws_s3_bucket.primary` using the `-replace` flag:

```bash
terraform apply -replace="aws_s3_bucket.primary"
```

Terraform planned a destroy-then-create for `aws_s3_bucket.primary` and also picked up the previously removed `aws_s3_bucket.example2` as a new resource to create, demonstrating how removing from state causes Terraform to re-plan creation.

**Screenshot:** `screenshots/ReplacingResource.png`

---

### 10. Handling Locked State

Simulated a locked state condition by running `terraform apply` in the background and immediately attempting a concurrent `terraform plan`:

```bash
terraform apply &
APPLY_PID=$!
sleep 2
terraform plan
# Error: Error acquiring the state lock
```

The lock error included the Lock ID (`4a3812cd-a142-add4-60e4-06659d7929ac`), operation type, and timestamp. Attempted `terraform force-unlock` with that ID:

```bash
terraform force-unlock 4a3812cd-a142-add4-60e4-06659d7929ac
# Local state cannot be unlocked by another process
```

Because local state (`.tfstate` file) can only be unlocked by terminating the holding process, resolved it by killing the background apply:

```bash
kill $APPLY_PID
```

> **Key insight:** `force-unlock` is primarily useful with remote backends (S3 + DynamoDB, Terraform Cloud) where a crashed process leaves a dangling lock. Local state is self-resolving once the holding process exits.

**Screenshots:** `screenshots/handlingLockedState.png`, `screenshots/forcingUnlock.png`

---

## Key Learnings

- **State is the source of truth** — Terraform compares desired configuration against state, not directly against AWS. Resources outside state are invisible to Terraform.
- **Import brings existing resources under management** — but configuration must be written manually to match the real resource's attributes.
- **Drift detection requires a plan or refresh** — `terraform plan` re-reads real infrastructure and compares to state, surfacing drift automatically.
- **`state mv` prevents destroy/recreate on renames** — critical for renaming resources or refactoring modules without causing downtime.
- **`state rm` decouples resource from Terraform without destroying it** — useful for handing off ownership or excluding resources from a stack.
- **State backups are essential** — before any manual state operation, always run `terraform state pull > backup.json`.
- **Local state locks differently from remote** — `force-unlock` is a remote-backend tool; local locks resolve by killing the holding process.

---

## Safety Tips

- Always backup state before any manual operation: `terraform state pull > backup-$(date +%s).json`
- Use remote state (S3 + DynamoDB or Terraform Cloud) with versioning enabled in production
- Test all state operations in a non-production environment first
- Never manually edit `.tfstate` files — use state commands or `state push` with a validated JSON
- Treat `terraform state push` as a last resort; prefer state commands that are auditable

---

## Commands Cheat Sheet

See [state-commands-cheatsheet.md](state-commands-cheatsheet.md) for the full reference of all state commands used in this lab.
