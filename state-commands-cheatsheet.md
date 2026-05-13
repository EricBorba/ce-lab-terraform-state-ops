# Terraform State Commands Cheat Sheet

## Inspection

```bash
terraform state list                          # List all resources tracked in state
terraform state show <resource_address>       # Show full attributes of one resource
terraform show                                # Show human-readable view of entire state
terraform show -json | jq '.'                 # State as structured JSON
```

## Modification

```bash
terraform state mv <source> <destination>     # Rename resource address in state (no destroy)
terraform state rm <resource_address>         # Remove from state without destroying in AWS
terraform state pull > backup.json            # Backup state to local file
terraform state push backup.json              # Restore state from file (use with extreme caution!)
```

## Import & Replace

```bash
terraform import <resource_address> <resource_id>   # Bring existing resource under Terraform management
terraform apply -replace="<resource_address>"       # Force destroy and recreate a specific resource
```

## Troubleshooting

```bash
terraform refresh                             # Sync state with real infrastructure (detect drift)
terraform force-unlock <lock_id>              # Force-release a stuck remote state lock
# Note: local state locks resolve by killing the holding process, not via force-unlock
```
