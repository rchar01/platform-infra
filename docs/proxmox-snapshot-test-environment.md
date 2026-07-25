# Proxmox Snapshot Test Environment Handoff

## Goal

Add an isolated, reusable OpenTofu environment that provisions two disposable
Proxmox VMs for live acceptance testing of
`platform-proxmox-vm-snapshot` from `platform-tools`.

Keep the environment definitions for future acceptance runs, but create the
VMs only while testing and destroy them afterward.

## Current Context

- The private inventory and local OpenTofu state were reviewed before this
  handoff was written.
- Every existing managed VM has an active platform role; none is designated as
  a disposable snapshot-test target.
- Reusing an existing VM would expose a real service to disk rollback,
  configuration rollback, and power-state changes.
- Existing environment roots now derive both `managed-by-tofu` and their
  environment name. Redundant public and private dev tags were removed as part
  of the tag-reconciliation checkpoint; live plans still gate any apply.
- Real VM names, IDs, addresses, node names, storage names, and template IDs
  belong in `platform-private` and must not be copied into this public plan.

## Decisions

- Use two dedicated VMs rather than any existing platform VM.
- Add an independent `environments/snapshot-test` root and state.
- Automatically add `managed-by-tofu` and the root's environment name to every
  VM managed by an environment root.
- Give the two VMs a shared `snapshot-test` environment tag so the snapshot
  tool can exercise serial multi-VM behavior.
- Keep guest configuration minimal; these VMs do not host platform services
  and do not need normal `platform-config` service enrollment.
- Destroy the VMs after acceptance while retaining their OpenTofu and private
  configuration for later runs.
- Do not deliberately induce live locks, storage failures, target drift, or
  partial operations. Those failure paths remain fake-backed tests.

## Scope

- Add the public `snapshot-test` environment root.
- Add matching private tfvars and environment-shell configuration.
- Make environment tags automatic for all roots.
- Reconcile manually duplicated public and private environment tags. If every
  VM already has its environment tag, the combined change must not alter the
  effective tag set; otherwise review and approve only the expected metadata
  update.
- Document initialization, state isolation, testing, and destruction.
- Validate plans for `homelab`, `dev`, and `snapshot-test` independently.
- Provision and destroy the test VMs only after explicit plan approval.

## Non-Goals

- Do not configure applications or platform services inside the test VMs.
- Do not add the VMs to normal Ansible service inventories.
- Do not modify existing service VMs for snapshot acceptance testing.
- Do not store API tokens, private keys, state, or plan files in Git.
- Do not automate live snapshot rollback in CI.
- Do not add remote state solely for this local acceptance environment.

## Public Test Shape

Use neutral public examples. Put real values only in
`platform-private/infra/snapshot-test.tfvars`.

| Property | Test VM 1 | Test VM 2 |
| --- | --- | --- |
| Inventory key | `example-snapshot-test-01` | `example-snapshot-test-02` |
| Hostname | `example-snapshot-test-01.example.test` | `example-snapshot-test-02.example.test` |
| VMID | `<unused-test-vmid-1>` | `<unused-test-vmid-2>` |
| Address | `192.0.2.74/24` | `192.0.2.75/24` |
| Explicit tags | `rocky`, `disposable` | `rocky`, `disposable` |
| CPU | 2 cores | 2 cores |
| Memory | 2048 MiB | 2048 MiB |
| Boot disk | 20 GiB | 20 GiB |
| Additional disk | 5 GiB on `scsi1` | 5 GiB on `scsi1` |

The environment root must add `managed-by-tofu` and `snapshot-test`; private
VM declarations must not need to repeat them.

## Phase 1: Automatic Environment Tags

- [x] Update `environments/homelab/locals.tf` so `default_tags` contains
      `managed-by-tofu` and `local.environment`.
- [x] Update `environments/dev/locals.tf` the same way.
- [x] Use the same rule in `environments/snapshot-test/locals.tf`.
- [x] Preserve `sort(distinct(var.tags))` in `modules/proxmox-vm/main.tf` so
      migration-time duplicate tags remain harmless.
- [x] Remove manually repeated environment tags from public examples and the
      corresponding private VM declarations in the same reviewed checkpoint.
- [x] Confirm each existing-root plan contains either no effective tag change
      or only the explicitly reviewed in-place environment-tag update.
- [ ] Confirm no existing-root plan contains a VM replacement, deletion, disk,
      CPU, memory, or network change.
- [ ] Obtain explicit approval before applying metadata changes to existing
      VMs.

Use this root-local pattern:

```hcl
locals {
  environment  = "snapshot-test"
  default_tags = ["managed-by-tofu", local.environment]
}
```

Treat tag reconciliation as a separate operational checkpoint before creating
the snapshot-test VMs. Do not apply between adding root-derived tags and
removing equivalent public/private tags. Review the combined existing-root
plans first.

## Phase 2: Public Environment Root

Create `environments/snapshot-test/` following the existing environment-root
structure:

- [x] Add `main.tf` using `../../modules/proxmox-vm` with
      `for_each = var.vms`.
- [x] Add `locals.tf` with `environment = "snapshot-test"`, automatic tags,
      config-root resolution, token-file resolution, and per-VM SSH key paths.
- [x] Add `variables.tf` with the existing root input contract.
- [x] Add `outputs.tf` with VM names, IDs, configured addresses, guest-agent
      addresses, and the inventory handoff map.
- [x] Add `providers.tf` and `versions.tf` matching the supported OpenTofu and
      `bpg/proxmox` constraints.
- [x] Add `terraform.tfvars.example` using only RFC 5737 addresses and neutral
      identifiers.
- [x] Add `README.md` describing the root as disposable and state-isolated.
- [x] Run `tofu init` and include `.terraform.lock.hcl` with the root change.
- [x] Confirm state, plans, and `.terraform/` remain ignored.

Reuse the existing module. Do not add a second snapshot-specific VM module.

## Phase 3: Private Configuration

In `platform-private/infra/`:

- [x] Add `snapshot-test.tfvars` with the reviewed private endpoint, node,
      bridge, storage, DNS, gateway, template, VMIDs, and addresses.
- [x] Add exactly two disposable VM declarations with a small additional disk
      so live acceptance exercises multi-disk snapshots.
- [x] Add `snapshot-test.tofu.env` that sets `TF_CLI_ARGS_plan` and
      `TF_CLI_ARGS_destroy` to the matching tfvars and explicitly unsets
      `TF_CLI_ARGS_apply`.
- [x] Require saved-plan apply for this environment. A saved plan already
      contains its input values, and OpenTofu rejects `-var` or `-var-file`
      arguments while applying it.
- [x] Reference the outside-Git token file; do not embed a token.
- [x] Check candidate VMIDs against live Proxmox before planning.
- [x] Check candidate addresses against DHCP, DNS, and network inventory before
      generating the final provisioning plan.
- [x] Do not commit generated private keys.

Generate dedicated cloud-init SSH keys from the public repository root:

```bash
make init-ssh ENV=snapshot-test PRIVATE=1
```

The expected path pattern is:

```text
~/.ssh/platform-infra-snapshot-test-<vm-key>-cloud-init_ed25519
```

## Phase 4: Documentation Integration

- [x] Add this document to `docs/README.md`.
- [x] Update `README.md` to list the new root and matching private files.
- [x] Update `docs/workflow.md` with setup, plan, apply, and destroy commands.
- [x] Update `docs/requirements.md` with private config expectations.
- [x] Update `docs/state.md` with the new independent-state invariant.
- [x] Update `docs/troubleshooting.md` with root/tfvars mismatch guidance.
- [x] Update `docs/ci.md` so secret-free validation includes `snapshot-test`.
- [x] Update `docs/roadmap.md` with the disposable snapshot acceptance
      milestone.
- [x] Update `AGENTS.md` with the lasting snapshot-test ownership and safety
      rules.
- [x] Update the current `Unreleased` sections in `NEWS.md` and
      `CHANGELOG.md`.

Documentation must state that snapshots are temporary rollback points, not
backups, and that environment operations are serial rather than atomic.

## Phase 5: Static Verification And Private Plans

Run from the `platform-infra` repository root:

```bash
make verify ENV=homelab
make verify ENV=dev
make verify ENV=snapshot-test
```

Validation gate:

- [x] OpenTofu formatting passes.
- [x] All three roots initialize and validate.
- [x] Existing Make and SSH-key helpers accept `ENV=snapshot-test` without
      special cases.
- [x] Public examples contain only documentation addresses and neutral names.
- [x] No state, plan, token, key, or private value is staged.
- [x] `git diff --check` passes.
- [x] Final diffs in both repositories contain no unrelated changes.

`make verify` does not run `tofu plan`. After static checks, run native private
plans independently from each matching root after sourcing its matching
`.tofu.env` file. The homelab and dev plans validate the tag-reconciliation
checkpoint; the snapshot-test plan validates exactly two new VM creates. Never
cross-use tfvars or state between roots.

Run the publication checks before committing public changes:

```bash
git grep -n -E '192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.'
git grep -n -E 'BEGIN .*PRIVATE KEY|proxmox_api_token\s*=|TOKEN_SECRET|password|secret'
```

Review every match rather than assuming the search is clean.

## Phase 6: Read-Only Live Preflight

Before applying:

- [x] Confirm the target is a supported single-node Proxmox VE 9 host.
- [x] Confirm both candidate VMIDs are unused.
- [x] Confirm both candidate addresses are unused through authoritative DHCP
      and network inventory.
- [x] Confirm the selected template exists and can be cloned.
- [x] Confirm the selected storage supports VM snapshots.
- [x] Confirm storage has room for two full clones, two additional disks, and
      saved memory state during testing.
- [x] Confirm the Proxmox host has `bash`, `pvesh`, and `jq`, plus `qm` for
      mutations.
- [x] Confirm an SSH operator workstation has local `bash`, `ssh`, and `jq`.
- [x] Confirm the run is specifically against a single-node Proxmox VE 9 host;
      other Proxmox versions and multi-node clusters are outside this
      acceptance scope.
- [x] Record only sanitized evidence in the public progress log.

Stop if any candidate identifier is already in use. Do not silently choose new
private values without updating and reviewing the private configuration.

## Phase 7: Plan And Apply

From `environments/snapshot-test`:

```bash
source "../../../platform-private/infra/snapshot-test.tofu.env"
tofu plan -out=snapshot-test.tfplan
```

Approval gate:

- [x] The plan contains exactly two VM creates.
- [x] No existing VM is updated, replaced, stopped, or destroyed.
- [x] Names, VMIDs, disks, addresses, tags, and SSH keys match the reviewed
      private values.
- [ ] The user explicitly approves the generated saved plan. Provisioning was
      authorized conditionally before regeneration, and machine inspection
      confirmed exactly the two reviewed creates and no other actions, but no
      separate post-generation approval was recorded.

Apply the saved plan without injecting variable arguments:

```bash
TF_CLI_ARGS_apply= tofu apply snapshot-test.tfplan
```

Do not replace this with an unsaved `tofu apply`. The empty command-local
`TF_CLI_ARGS_apply` also protects against arguments left in the shell after a
different environment file was sourced.

After apply:

- [x] Both VMs appear in OpenTofu state and Proxmox.
- [x] Both contain exactly one `managed-by-tofu` tag and exactly one
      `snapshot-test` tag while retaining the reviewed explicit tags.
- [x] No unrelated VM has the `snapshot-test` tag.
- [x] Guest SSH works with each dedicated key.
- [x] QEMU guest-agent status is healthy.
- [x] Boot and additional disks are visible.
- [x] Neither VM belongs to a platform service inventory.

## Phase 8: Platform-Tools Acceptance Handoff

The environment is ready when this command returns exactly the two disposable
VMs:

```bash
platform-proxmox-vm-snapshot list \
  --ssh root@<proxmox-host> \
  --environment snapshot-test
```

The `platform-tools` acceptance run should cover:

- [ ] VMID selection.
- [ ] Exact-name selection.
- [ ] `snapshot-test` environment selection.
- [ ] Create, list, rollback, and delete.
- [ ] Dry-run and interactive confirmation.
- [ ] Explicit `--yes` after interactive confirmation is proven.
- [ ] Default and explicit descriptions.
- [ ] `--include-memory`.
- [ ] Rollback stopped-state behavior.
- [ ] `--start-after-rollback`.
- [ ] Local read-only execution.
- [ ] SSH execution and identity-file handling.
- [ ] Direct structured Proxmox verification after each operation.

Immediately before every environment create, rollback, or delete:

- [ ] Query both VMs directly and confirm each has exact `managed-by-tofu` and
      `snapshot-test` tags.
- [ ] Run the matching environment dry-run or list operation again.
- [ ] Compare the complete resolved VMID set with the two reviewed private
      targets and current Proxmox inventory.
- [ ] Abort if either target is missing or any additional target appears.
- [ ] Abort if either required tag is missing or any unrelated VM has the
      `snapshot-test` tag.
- [ ] Record explicit operator approval for that operation and exact target
      set.

Observable rollback acceptance belongs to a private or `platform-tools`-owned
temporary test fixture, not to this repository. `platform-infra` only attaches
the additional disk and provides initial access. The owning acceptance runbook
must produce these observable outcomes without adding partitioning, formatting,
mounting, or guest marker implementation here:

- [ ] Before a disk-only snapshot, write distinct baseline markers to the boot
      disk and the temporarily prepared additional disk, then flush writes.
- [ ] After the snapshot, replace both markers and flush writes again.
- [ ] Roll back without automatic restart, verify Proxmox reports `stopped`,
      start the guest deliberately, and confirm both baseline markers return.
- [ ] Before a memory snapshot, write a baseline marker in `/dev/shm`, create a
      saved-memory snapshot, replace the marker, and roll back with
      `--start-after-rollback`.
- [ ] Confirm the VM reaches `running` and the original `/dev/shm` marker is
      restored, demonstrating observable saved-memory restoration.
- [ ] Keep temporary disk preparation and marker implementation outside
      `platform-infra` and remove it with the disposable VMs.

Keep live lock, drift, storage-failure, and partial-operation injection out of
this acceptance run. Existing fake-backed tests cover those unsafe paths.

## Phase 9: Destruction

After every test snapshot has been deleted, run from
`environments/snapshot-test`:

```bash
source "../../../platform-private/infra/snapshot-test.tofu.env"
tofu plan -destroy -out=snapshot-test-destroy.tfplan
```

Destruction approval gate:

- [ ] The destroy plan contains exactly the two test VMs.
- [ ] No other resource is present in the destroy plan.
- [ ] The user explicitly approves the reviewed destroy plan.
- [ ] Apply the saved destroy plan without variable arguments:
      `TF_CLI_ARGS_apply= tofu apply snapshot-test-destroy.tfplan`.
- [ ] Confirm both VMs are absent from Proxmox and OpenTofu state.
- [ ] Remove ignored plan files.
- [ ] Retain the public root and private configuration for future runs.

If snapshot deletion, rollback, or lock handling fails:

- [ ] Stop further acceptance operations and preserve OpenTofu state and the
      sanitized operation record.
- [ ] Re-list both targets and snapshots and inspect the current Proxmox lock
      state before attempting cleanup.
- [ ] Correct the underlying task or lock failure and retry normal deletion
      without forced metadata-only deletion.
- [ ] If normal deletion cannot complete, prepare a fresh destroy plan and use
      it only when it still contains exactly the two disposable VMs and the
      user explicitly authorizes VM destruction with snapshots present.
- [ ] If reviewed OpenTofu destruction is also blocked, retain the VMs and
      escalate to a separately authorized break-glass and state-repair
      procedure. Do not issue an ad hoc manual VM destroy from this plan.

## Acceptance Criteria

- The test environment has independent state.
- Existing platform VMs are never snapshot-test targets.
- Every environment root derives its environment tag automatically.
- `--environment snapshot-test` resolves exactly two disposable VMs.
- Existing-root plans contain no unreviewed replacements or destructive
  changes.
- The test pair can be recreated and destroyed through normal OpenTofu
  workflows.
- Live acceptance covers single-VM and serial multi-VM behavior.
- No secret or private infrastructure value enters the public repository.
- Sanitized acceptance evidence is recorded in this document's progress log.

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| Candidate VMIDs or addresses are already used live. | Check Proxmox, DHCP, DNS, and network inventory before plan or apply. |
| Automatic tags cause unexpected existing-VM changes. | Review separate existing-root plans and require approval before metadata apply. |
| The wrong private tfvars are used from the new root. | Use a dedicated `.tofu.env`, document the invariant, and inspect every plan target. |
| Test storage usage is larger than expected. | Check free space before apply and memory snapshot creation; destroy the VMs after acceptance. |
| Multi-VM rollback produces inconsistent guest state. | Use only the disposable pair and treat operations as serial and non-atomic. |
| Local state is lost before cleanup. | Preserve the environment state until destroy completes; never delete VMs manually during the normal workflow. |
| Private details leak into the public repository. | Keep real values in `platform-private` and run the publication checklist before commit. |

## Open Questions

- [x] Private VMIDs and addresses were confirmed unused before provisioning.
- [x] The selected datastore has enough capacity for both test VMs and
      memory snapshots.
- [x] Detailed evidence uses the private infrastructure acceptance log under
      `platform-private/infra/plans/`.

## Progress Log

| Date | Update | Evidence |
| --- | --- | --- |
| 2026-07-25 | Reviewed private declarations and local state; all existing VMs have active roles and no disposable target exists. Chose two disposable VMs in an isolated root. | Local `platform-private` inventory and `platform-infra` state review; private identifiers intentionally omitted |
| 2026-07-25 | Handoff plan added. No OpenTofu files or infrastructure changed. | `docs/proxmox-snapshot-test-environment.md` |
| 2026-07-25 | Chose a separate existing-root tag reconciliation checkpoint and private detailed acceptance evidence. | User decisions recorded before implementation |
| 2026-07-25 | Added root-derived environment tags and removed redundant dev tags from public and private declarations. Static validation passed; live plans remain pending. | `environments/{homelab,dev}/locals.tf`, public examples, private `dev.tfvars` |
| 2026-07-25 | Homelab and dev private plans completed with no create, replace, or destroy actions. Dev has no effective tag change; homelab adds its environment tag. Both plans also contain previously pending discard and IO-thread disk updates, so no tag apply was performed. | Redacted local plan review; private identifiers omitted |
| 2026-07-25 | Added and initialized the state-isolated public snapshot-test root with two neutral disposable VM examples. | `environments/snapshot-test/`; OpenTofu 1.11.7 validation with provider 0.106.0 |
| 2026-07-25 | Added private snapshot-test values, environment arguments, acceptance log, and dedicated SSH keys after live collision/tool/storage preflight. | `platform-private/infra/`; generated keys remain outside Git |
| 2026-07-25 | Created a saved private plan with exactly two VM creates and no other actions. The plan remains unapplied pending explicit approval. | Ignored `environments/snapshot-test/snapshot-test.tfplan`; private details omitted |
| 2026-07-25 | Public verification and publication scans passed. Candidate addresses had no ping or resolver response, but authoritative DHCP/network confirmation remains pending. | Three-root `make verify`; tracked-content publication scan; sanitized private preflight |
| 2026-07-25 | After address confirmation and explicit conditional provisioning authorization, regenerated, machine-validated, and applied an exact two-create saved plan. No separate post-generation approval was recorded. Both disposable VMs are running with the reviewed identities, tags, disks, SSH access, and healthy guest agents; a post-apply plan reports no drift. No disk formatting or snapshot mutation was performed. | OpenTofu state and refresh plan; direct Proxmox and guest verification; private acceptance log |

## Decision Log

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-07-25 | Use two dedicated disposable VMs. | One VM cannot exercise real serial environment behavior; existing VMs host active services. |
| 2026-07-25 | Use an independent `snapshot-test` root. | Separate state prevents acceptance resources from sharing the active dev state. |
| 2026-07-25 | Destroy test VMs after each acceptance run but retain definitions. | This preserves repeatability without permanent compute and storage cost. |
| 2026-07-25 | Keep real target values in `platform-private`. | The public repository policy forbids publishing private infrastructure identifiers. |
| 2026-07-25 | Reconcile existing-root tags before creating test VMs. | This proves environment selection is safe before snapshot mutations are enabled. |
| 2026-07-25 | Keep detailed live acceptance evidence private. | VM identities and environment details must not enter the public repository. |
