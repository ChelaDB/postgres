# Cherry-picks from Neon's Postgres branches

This file decides, for each major, which of Neon's own Postgres commits we carry on our `REL_1x_STABLE_cheladb` branches. Neon's `REL_1x_STABLE_neon` branches kept moving after the commits our fork pins, while Neon's public `neon` repository (and with it `pgxn/neon`) effectively stopped at those pins. Many of the later Postgres commits only make sense with a newer, unpublished neon extension. We take the self-contained fixes and leave the rest.

Triage date: 2026-10-01. Extension checked against: `ChelaDB/neon` at `fa504217c61bbcaf5c512d75830564541f917f8f` (its `vendor/revisions.json` pins exactly the commits below, and its `pgxn/neon` last changed on 2025-07-30).

| Major | Pin (our branch head) | Pin minor | Target minor | Neon branch head at triage |
|---|---|---|---|---|
| 17 | `1e01fcea2a6` | 17.5 | 17.11 | `56692dfb680` |
| 16 | `a42351fcd41` | 16.9 | 16.15 | `59027122a97` |
| 15 | `2aaab3bb4a1` | 15.13 | 15.19 | `6056289bb69` |
| 14 | `2155cb165d0` | 14.18 | 14.24 | `74c6ea95999` |

## Method

1. Candidates: `git log --no-merges <pin>..upstream-neon/REL_<x>_STABLE_neon ^REL_<x>_<target>`. Upstream commits that Neon brought in through its minor merges are reachable from the target tag, so they drop out here; our own minor merges (plan Tasks 6 and 7) bring them.
2. Upstream equivalents that Neon cherry-picked separately (different sha): `git cherry postgres/REL_<x>_STABLE upstream-neon/REL_<x>_STABLE_neon`, plus matching author, date and subject against the target tag. These are `skip-upstream`, with the first upstream minor that contains them.
3. Every remaining commit was read (`git show --stat`, then the diff), and each hook, GUC, lock and symbol it touches was grepped in `git grep <sym> fa504217 -- pgxn/neon` in `ChelaDB/neon`.
4. Every pick was test-applied in a scratch worktree: our branch head, `git merge REL_<x>_<target>` (the merge conflicts are in files no pick touches; they were resolved as "ours" for the test only), then `git cherry-pick -x` of the picks in the order below. The objects the picks touch were then compiled (`configure`, `make generated-headers`, then the touched `.o` files).

## Classes

- **pick**: a self-contained correctness or security fix that needs nothing our `pgxn/neon` lacks and doesn't depend on a non-picked Neon commit. Plan Task 8 applies these, in the "Apply order" below, with `git cherry-pick -x`, after the minor merges.
- **skip-ext**: needs neon-extension code that our `pgxn/neon` at `fa504217` doesn't have. Either it removes or moves something our extension still uses (it wouldn't compile), or it adds a hook or GUC variable that only a newer extension sets (it would be dead code).
- **skip-feature**: a Databricks or Neon feature, tooling or CI change (`BRC-`/`LKB-` tickets, Unity Catalog, pgbench additions, prewarm, pg_waldump features, CI workflows, test-module backports, diagnostics, a commit and its revert).
- **skip-upstream**: an upstream PostgreSQL fix that the target minor already contains; our minor merge brings it.

## Spec candidates

The spec listed these as likely picks. All of the Postgres-side fixes turned out to be upstream back-patches, so the minor merges bring them. None needs a separate cherry-pick.

| Candidate | Decision | Where it comes from |
|---|---|---|
| Set next multixid's offset when creating a new multixid | skip-upstream | 17.8 / 16.12 / 15.16 / 14.21 (upstream `8ba61bc0638` on 17; Neon has it only via its minor merge) |
| Add check for invalid offset at multixid truncation | skip-upstream | 17.8 / 16.12 / 15.16 / 14.21 (`d3ad4cef6ea` on 17) |
| Clarify comment on multixid offset wraparound check | skip-upstream | 17.8 / 16.12 / 15.16 / 14.21 (`cd1a887fe9b` on 17) |
| Escalate ERRORs during async notify processing to FATAL | skip-upstream | 17.8 / 16.12 / 15.16 / 14.21 (`b821c92920f` on 17) |
| Clear 'xid' in dummy async notify entries written to fill up pages | skip-upstream | 17.8 / 16.12 / 15.16 / 14.21 (`d80d5f09950` on 17) |
| Do not emit WAL for unlogged BRIN indexes | skip-upstream | 17.8 / 16.12 / 15.16 / 14.21 (`4b6d096a0f9` on 17) |
| Fix UC permissions check after CVE-2025-8713 fix | skip-feature | Only extends the Databricks Unity Catalog hook (`ExecutorUnityCatalogCheckPerms_hook`, added by the skipped BRC-3414 commit) to `subquery_planner()`. The CVE-2025-8713 fix itself ("Fix security checks in selectivity estimation functions") is upstream in 17.6 / 16.10 / 15.14 / 14.19. Neon carries this commit on v17 and v16 only. |
| Improve stability of btree page split on ERRORs | **pick** (all four majors) | Upstream master `85e0ff62b68` (PG 19), not back-patched, so no minor brings it. |

## v17 (17.5 → 17.11)

Counts: pick 5, skip-ext 13, skip-feature 28, skip-upstream 4, total 50.

| sha | subject | class | reason |
|---|---|---|---|
| `db68e552958` | pg waldump improvements (#714) | skip-feature | pg_waldump descriptions for Neon-specific records; tooling feature, not a fix. |
| `c93daf0889e` | Refactor SLRU download interface between Postgres and the neon extension | skip-ext | Replaces `f_smgr.smgr_read_slru_segment` with `read_slru_segment_hook` and drops `neon_use_communicator_worker`; our pgxn/neon still uses the old smgr callback (`pagestore_smgr.c`), so it would not compile. |
| `73cb438f714` | CI: Only test Postgres branch. (#723) | skip-feature | Neon's GitHub workflow; our CI is our own. |
| `e4030cd5aa0` | WALRecevier read password from env var (#40) | skip-feature | Databricks auth (`NEON_AUTH_TOKEN` env var for the walreceiver); start of a chain that ends in an ext-side hook. |
| `04c7d4ff0f3` | [BRC-3414] Add PG hook for oauth token permission check | skip-feature | Databricks Unity Catalog (`ExecutorUnityCatalogCheckPerms_hook`); no consumer in our pgxn/neon. |
| `3c95ad70f51` | Add hook in pg_signal_backend() | skip-feature | New hook for a Databricks/Neon extension feature; no consumer in our pgxn/neon. |
| `e7cdfe2e6d2` | [BRC-3414] Add hook for backup token access check on SCHEMAs (#59) | skip-feature | Databricks Unity Catalog (`NamespaceUnityCatalogAccess_hook`); no consumer in our pgxn/neon. |
| `1b53132f28a` | Add global temp file size limit | skip-ext | Adds `CheckTempFileSize_hook`; the limit itself lives in a newer neon extension (no `CheckTempFileSize` in our pgxn/neon). Inert on its own. |
| `d90e56f051f` | Do not create new timeline for replica promotion (#746) | pick | Neon recovery fix: with `neon.signal` the promoted replica keeps its timeline. Neon storage assumes TLI 1 (`postgres_ffi::PG_TLI`, used by basebackup and safekeepers), and fa504217 ships replica promotion (`compute_promote.rs`). Only touches Neon-specific code that is already on our branch; no ext symbol involved. Prerequisite of "Fix initialization of the WAL buffer at startup". |
| `1f320d1cc98` | don't force FPI if checksums are enabled | skip-feature | Neon WAL-volume optimisation (redefines `XLogHintBitIsNeeded()`); changes durability semantics, not a fix. Revisit as a product decision if we enable data checksums. |
| `a42a079b61c` | Remove unnecessary set_lwlsn_block_* hooks | skip-ext | Removes `set_lwlsn_block_hook`/`_range_hook`/`_v_hook`, which our pgxn/neon (`neon_lwlsncache.c`) still sets; would not compile. |
| `59a3ab69fda` | Add --load-records option to pg_waldump | skip-feature | Neon pg_waldump feature (`--load-records`). |
| `60bb7225ab9` | Initialize XLogReader to dumop wal record | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `54d1c47bf93` | Add missed update of long_options | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `77d9ea5066c` | Fix bugs | skip-feature | Follow-up of the pg_waldump `--load-records` feature (pg_waldump.c only). |
| `d142c82a051` | Fix compiler warning | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `75cadabb469` | Fix compiler warnings | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `d38a9f0d95f` | Add check for fread/fwrite result | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `99ab234475c` | Set xl_prev correctly if replica is promoted without replaying any records | pick | Correctness fix in Neon's startup path (`NeonRecoveryRequested`, `neonLastRec`, both on our branch): a replica promoted before replaying any record wrote an end-of-recovery record with a wrong `xl_prev`, breaking replicas and logical replication across the switchover. No ext dependency. |
| `84bec44452d` | Fix initialization of the WAL buffer at startup | pick | Correctness fix in Neon's `FinishWalRecovery()` path: wrote past the temp page when end-of-log is page-aligned (assert failure) and copied an uninitialised read buffer into the first WAL page. Needs "Do not create new timeline for replica promotion" first (it rewrites that commit's hunk). |
| `d61c865bce3` | CI: fix GitHub Actions Workflow | skip-feature | Neon's GitHub workflow. |
| `6bc9ef8980f` | Improve stability of btree page split on ERRORs | pick | Backport of upstream master 85e0ff62b68 (PG 19 only, not back-patched, so no minor brings it). Avoids VACUUM seeing a half-split page as corruption after an ERROR during `_bt_split()`. Same diff as upstream plus an `INJECTION_POINT("bt-split")` (a no-op unless attached). nbtinsert.c only. |
| `aa1f746f58a` | pg prewarm heap scan (#791) | skip-feature | pg_prewarm feature (heap-scan mode). |
| `0d47993482a` | Fix UC permissions check after CVE-2025-8713 fix | skip-feature | Only adds the Databricks Unity Catalog hook call to `subquery_planner()` and tidies it in `ExecCheckPermissions()`; depends on the skipped BRC-3414 hook. The CVE-2025-8713 fix itself (a85eddab23f and back-branch equivalents) is upstream and came with 17.6/16.10/15.14/14.19. |
| `e9b9346635d` | [LKB-5974][PG_17] Add the ability to reduce FPI (#792) | skip-feature | Databricks (LKB-5974) FPI-reduction feature; changes WAL emission. |
| `9aa0b42bfd4` | Move LastWrittenLsnLock to neon extension | skip-ext | Removes the built-in `LastWrittenLsnLock`; our pgxn/neon (`neon_lwlsncache.c`) still uses it; would not compile. |
| `bdc89562a0f` | Move LastWrittenLsnLock to neon extension | skip-ext | Removes the built-in `LastWrittenLsnLock`; our pgxn/neon (`neon_lwlsncache.c`) still uses it; would not compile. |
| `efc65b3326f` | Move NEON_AUTH_TOKEN to a builtin GUC | skip-ext | Part of the walreceiver-auth chain that ends with the GUC moved into a newer neon extension (`neon_storage_token`, absent from our pgxn/neon). |
| `76ac5437bc5` | Fix amcheck's handling of incomplete root splits in B-tree | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 17.8. |
| `990cc82d5af` | Fix amcheck's handling of half-dead B-tree pages | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 17.8. |
| `71fc525e5e1` | pgbench: Add --init-batch-size with automatic retry on disconnect (#820) | skip-feature | pgbench addition. |
| `9a0ca1eb168` | Add wait event hooks for extensions (#836) | skip-ext | New wait-event hooks for a newer neon extension; no consumer in our pgxn/neon. |
| `65d8de10869` | pgbench: Add latency percentile reporting with histogram-based tracking (#834) | skip-feature | pgbench addition. |
| `1bfe87e6401` | Move neon_storage_token to PGC_SUSET | skip-ext | `neon_storage_token` GUC chain; moved into the neon extension next, absent from our pgxn/neon. |
| `e429a5992cb` | Move the neon_storage_token GUC definition to the neon extension | skip-ext | Removes the GUC from core; the definition lives in a newer neon extension that we don't have. |
| `e5c8790c89f` | pgbench: fix `-Wsometimes-uninitialized` warning | skip-feature | Warning fix in the skipped pgbench additions. |
| `81231ef96f9` | pgbench: fix `-Wunused-but-set-variable` warning | skip-feature | Warning fix in the skipped pgbench additions. |
| `3757d1f4979` | c (#863) | skip-feature | `ConfigOptionIsVisible()` change, reverted by the next commit; net no-op. |
| `9191344fe6d` | Revert "c (#863)" | skip-feature | Revert of the previous commit; net no-op. |
| `bdd173637d9` | Use a hook for getting the walreceiver password | skip-ext | Walreceiver password from a hook set by a newer neon extension (end of the `neon_storage_token` chain). |
| `ccb8ee23306` | Add get_pin_limit_hook | skip-ext | New hook consumed by a newer neon extension; no `get_pin_limit_hook` in our pgxn/neon. |
| `5fd26f4a167` | Fix SUBSTRING() for toasted multibyte characters. | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 17.9. |
| `6108b598c6b` | Don't reset 'latest_page_number' when replaying multixid truncation | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 17.9. |
| `a284a84b4e0` | Log stop of walreceiver | skip-feature | Diagnostic LOG line only, not a fix. |
| `3b8d478f83d` | Correctly handle contrecord in pg_waldump with --ignore option | pick | Fix in Neon's xlogreader `skip_page_validation` path (already on our branch; set only by `pg_waldump --ignore`, used by neon's `test_pg_waldump.py`): skip the continuation record instead of misreading it. Two lines, no server-path change. |
| `78de8d1547f` | Prevent possible search_path attacks | skip-ext | Core side of a superuser search_path hardening: `prohibit_superuser_overrides` is declared here but the GUC is defined in a newer neon extension (absent from our pgxn/neon), so it stays false and the code is inert. Security-relevant: worth our own design later. |
| `ab3853df3a6` | Add extension_is_visible_hook for filtering pg_available_extensions (#925) | skip-feature | New hook for a Databricks/Neon extension filter; no consumer in our pgxn/neon. |
| `6a0cb7e8f4a` | Move extension_is_visible_hook from fmgr.h/fmgr.c to extension.h/extension.c (#936) | skip-feature | Follow-up of the skipped extension_is_visible_hook. |
| `a48d9cae7cb` | Backport injection_points_attach() overload with library, function, private data | skip-feature | Test-module backport for Neon's tests. |
| `56692dfb680` | give startup process in replica priority to apply locks | skip-ext | `startupProcessLockPriority` is a GUC defined in a newer neon extension; inert without it. |

### Apply order (v17)

1. `d90e56f051f` Do not create new timeline for replica promotion (#746)
2. `99ab234475c` Set xl_prev correctly if replica is promoted without replaying any records
3. `84bec44452d` Fix initialization of the WAL buffer at startup
4. `6bc9ef8980f` Improve stability of btree page split on ERRORs
5. `3b8d478f83d` Correctly handle contrecord in pg_waldump with --ignore option

Test-apply on our v17 head merged with `REL_17_11`: all 5 applied cleanly with `git cherry-pick -x`, in this order, and `xlog.o`, `xlogrecovery.o`, `xlogreader.o`, `nbtinsert.o` compiled without warnings.
The first three are one chain: the WAL-buffer fix rewrites the hunk the timeline commit adds to `FinishWalRecovery()`, so keep that order.

## v16 (16.9 → 16.15)

Counts: pick 5, skip-ext 12, skip-feature 24, skip-upstream 4, total 45.

| sha | subject | class | reason |
|---|---|---|---|
| `7531b1c9c4c` | pg waldump improvements (#707) | skip-feature | pg_waldump descriptions for Neon-specific records; tooling feature, not a fix. |
| `782be25d8ca` | Refactor SLRU download interface between Postgres and the neon extension | skip-ext | Replaces `f_smgr.smgr_read_slru_segment` with `read_slru_segment_hook` and drops `neon_use_communicator_worker`; our pgxn/neon still uses the old smgr callback (`pagestore_smgr.c`), so it would not compile. |
| `0b59fde65eb` | CI: Only test Postgres branch. (#724) | skip-feature | Neon's GitHub workflow; our CI is our own. |
| `db44665f7cc` | WALRecevier read password from env var (#40) | skip-feature | Databricks auth (`NEON_AUTH_TOKEN` env var for the walreceiver); start of a chain that ends in an ext-side hook. |
| `cdd470152a7` | [BRC-3414] Add PG hook for oauth token permission check | skip-feature | Databricks Unity Catalog (`ExecutorUnityCatalogCheckPerms_hook`); no consumer in our pgxn/neon. |
| `db5b7fce687` | Add hook in pg_signal_backend() | skip-feature | New hook for a Databricks/Neon extension feature; no consumer in our pgxn/neon. |
| `984c0944c7a` | [BRC-3414] Add hook for backup token access check on SCHEMAs (#59) | skip-feature | Databricks Unity Catalog (`NamespaceUnityCatalogAccess_hook`); no consumer in our pgxn/neon. |
| `84ade857410` | Add global temp file size limit | skip-ext | Adds `CheckTempFileSize_hook`; the limit itself lives in a newer neon extension (no `CheckTempFileSize` in our pgxn/neon). Inert on its own. |
| `02083ed09d9` | Do not create new timeline for replica promotion (#745) | pick | Neon recovery fix: with `neon.signal` the promoted replica keeps its timeline. Neon storage assumes TLI 1 (`postgres_ffi::PG_TLI`, used by basebackup and safekeepers), and fa504217 ships replica promotion (`compute_promote.rs`). Only touches Neon-specific code that is already on our branch; no ext symbol involved. Prerequisite of "Fix initialization of the WAL buffer at startup". |
| `9c5978b4956` | don't force FPI if checksums are enabled | skip-feature | Neon WAL-volume optimisation (redefines `XLogHintBitIsNeeded()`); changes durability semantics, not a fix. Revisit as a product decision if we enable data checksums. |
| `02a153ca70c` | Remove unnecessary set_lwlsn_block_* hooks | skip-ext | Removes `set_lwlsn_block_hook`/`_range_hook`/`_v_hook`, which our pgxn/neon (`neon_lwlsncache.c`) still sets; would not compile. |
| `1bb96a0e60e` | Change how sorted GiST index build is handled with Neon storage in v14-v16 | skip-ext | Reorders GiST sorted build to WAL-log before `smgrextend()` without the unlogged-build calls; the stated purpose is a pgxn/neon cleanup (reinstate the empty-index check, drop the LFC hack) that our ext lacks. Our ext at fa504217 is built for the current order (check disabled for v14-16); no bug fixed on its own. |
| `c870a70f5be` | Add --load-records option | skip-feature | Neon pg_waldump feature (`--load-records`). |
| `967a29c8f80` | Fix compiler warning | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `d5514ac63e0` | Fix compiler warnings | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `41fb35fb322` | Add check for fread/fwrite result | skip-feature | Follow-up of the pg_waldump `--load-records` feature. |
| `46fed80932b` | Set xl_prev correctly if replica is promoted without replaying any records | pick | Correctness fix in Neon's startup path (`NeonRecoveryRequested`, `neonLastRec`, both on our branch): a replica promoted before replaying any record wrote an end-of-recovery record with a wrong `xl_prev`, breaking replicas and logical replication across the switchover. No ext dependency. |
| `63f41822177` | Fix initialization of the WAL buffer at startup | pick | Correctness fix in Neon's `FinishWalRecovery()` path: wrote past the temp page when end-of-log is page-aligned (assert failure) and copied an uninitialised read buffer into the first WAL page. Needs "Do not create new timeline for replica promotion" first (it rewrites that commit's hunk). |
| `10b394accc4` | CI: fix GitHub Actions Workflow | skip-feature | Neon's GitHub workflow. |
| `165f042b3ca` | Improve stability of btree page split on ERRORs | pick | Backport of upstream master 85e0ff62b68 (PG 19 only, not back-patched, so no minor brings it). Avoids VACUUM seeing a half-split page as corruption after an ERROR during `_bt_split()`. Same diff as upstream plus an `INJECTION_POINT("bt-split")` (a no-op unless attached). nbtinsert.c only. |
| `415ebe8c3b0` | pg prewarm heap scan (#790) | skip-feature | pg_prewarm feature (heap-scan mode). |
| `03740789732` | Fix UC permissions check after CVE-2025-8713 fix | skip-feature | Only adds the Databricks Unity Catalog hook call to `subquery_planner()` and tidies it in `ExecCheckPermissions()`; depends on the skipped BRC-3414 hook. The CVE-2025-8713 fix itself (a85eddab23f and back-branch equivalents) is upstream and came with 17.6/16.10/15.14/14.19. |
| `a4147054f68` | [LKB-5974][PG_16]Add the ability to reduce FPI (#807) | skip-feature | Databricks (LKB-5974) FPI-reduction feature; changes WAL emission. |
| `74c6bb6cc36` | Move LastWrittenLsnLock to neon extension | skip-ext | Removes the built-in `LastWrittenLsnLock`; our pgxn/neon (`neon_lwlsncache.c`) still uses it; would not compile. |
| `47873d31c32` | Move NEON_AUTH_TOKEN to a builtin GUC | skip-ext | Part of the walreceiver-auth chain that ends with the GUC moved into a newer neon extension (`neon_storage_token`, absent from our pgxn/neon). |
| `74350eaf8ed` | Fix amcheck's handling of incomplete root splits in B-tree | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 16.12. |
| `e4220e001fa` | Fix amcheck's handling of half-dead B-tree pages | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 16.12. |
| `cfbf2c3f397` | pgbench: Add latency percentile reporting with histogram-based tracking (#833) | skip-feature | pgbench addition. |
| `a0f7dafdf23` | Add wait event hooks for extensions (#835) | skip-ext | New wait-event hooks for a newer neon extension; no consumer in our pgxn/neon. |
| `9167f82529c` | Move neon_storage_token to PGC_SUSET | skip-ext | `neon_storage_token` GUC chain; moved into the neon extension next, absent from our pgxn/neon. |
| `f45eb12c840` | Move the neon_storage_token GUC definition to the neon extension | skip-ext | Removes the GUC from core; the definition lives in a newer neon extension that we don't have. |
| `c7cb4621b1c` | pgbench: fix `-Wsometimes-uninitialized` warning | skip-feature | Warning fix in the skipped pgbench additions. |
| `44848a35c27` | pgbench: fix `-Wunused-but-set-variable` warning | skip-feature | Warning fix in the skipped pgbench additions. |
| `81dcc34bb7f` | c (#857) | skip-feature | `ConfigOptionIsVisible()` change, reverted by the next commit; net no-op. |
| `df81397469a` | Revert "c (#857)" | skip-feature | Revert of the previous commit; net no-op. |
| `df20cf9ed4b` | Use a hook for getting the walreceiver password | skip-ext | Walreceiver password from a hook set by a newer neon extension (end of the `neon_storage_token` chain). |
| `1fa46ba0d8a` | Fix SUBSTRING() for toasted multibyte characters. | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 16.13. |
| `6d3029c39e8` | Don't reset 'latest_page_number' when replaying multixid truncation | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 16.13. |
| `0113957c221` | Log stop of walreceiver | skip-feature | Diagnostic LOG line only, not a fix. |
| `73723e26ece` | Correctly handle contrecord in pg_waldump with --ignore option | pick | Fix in Neon's xlogreader `skip_page_validation` path (already on our branch; set only by `pg_waldump --ignore`, used by neon's `test_pg_waldump.py`): skip the continuation record instead of misreading it. Two lines, no server-path change. |
| `8234b84c47b` | Prevent possible search_path attacks | skip-ext | Core side of a superuser search_path hardening: `prohibit_superuser_overrides` is declared here but the GUC is defined in a newer neon extension (absent from our pgxn/neon), so it stays false and the code is inert. Security-relevant: worth our own design later. |
| `ed61a140d9f` | Backport PG17 dynamic custom wait event infrastructure to PG16 (#931) | skip-feature | Backport of PG 17 infrastructure needed only by the skipped wait-event hooks. |
| `18380e7be35` | Add extension_is_visible_hook for filtering pg_available_extensions (#924) | skip-feature | New hook for a Databricks/Neon extension filter; no consumer in our pgxn/neon. |
| `8dbf2dda54d` | Move extension_is_visible_hook from fmgr.h/fmgr.c to extension.h/extension.c (#935) | skip-feature | Follow-up of the skipped extension_is_visible_hook. |
| `59027122a97` | give replica startup process priority in acquiring locks | skip-ext | `startupProcessLockPriority` is a GUC defined in a newer neon extension; inert without it. |

### Apply order (v16)

1. `02083ed09d9` Do not create new timeline for replica promotion (#745)
2. `46fed80932b` Set xl_prev correctly if replica is promoted without replaying any records
3. `63f41822177` Fix initialization of the WAL buffer at startup
4. `165f042b3ca` Improve stability of btree page split on ERRORs
5. `73723e26ece` Correctly handle contrecord in pg_waldump with --ignore option

Test-apply on our v16 head merged with `REL_16_15`: all 5 applied cleanly with `git cherry-pick -x`, in this order, and `xlog.o`, `xlogrecovery.o`, `xlogreader.o`, `nbtinsert.o` compiled without warnings.
The first three are one chain: the WAL-buffer fix rewrites the hunk the timeline commit adds to `FinishWalRecovery()`, so keep that order.

## v15 (15.13 → 15.19)

Counts: pick 5, skip-ext 10, skip-feature 10, skip-upstream 4, total 29.

| sha | subject | class | reason |
|---|---|---|---|
| `db8a674c049` | Refactor SLRU download interface between Postgres and the neon extension | skip-ext | Replaces `f_smgr.smgr_read_slru_segment` with `read_slru_segment_hook` and drops `neon_use_communicator_worker`; our pgxn/neon still uses the old smgr callback (`pagestore_smgr.c`), so it would not compile. |
| `93feb20a791` | CI: Only test Postgres branch. (#725) | skip-feature | Neon's GitHub workflow; our CI is our own. |
| `3e7c8e21966` | WALRecevier read password from env var (#40) | skip-feature | Databricks auth (`NEON_AUTH_TOKEN` env var for the walreceiver); start of a chain that ends in an ext-side hook. |
| `0e3242c7a3e` | [BRC-3414] Add hook for backup token access check on SCHEMAs (#59) | skip-feature | Databricks Unity Catalog (`NamespaceUnityCatalogAccess_hook`); no consumer in our pgxn/neon. |
| `68b1d38bb78` | Add global temp file size limit | skip-ext | Adds `CheckTempFileSize_hook`; the limit itself lives in a newer neon extension (no `CheckTempFileSize` in our pgxn/neon). Inert on its own. |
| `67f57716159` | Do not create new timeline for replica promotion (#747) | pick | Neon recovery fix: with `neon.signal` the promoted replica keeps its timeline. Neon storage assumes TLI 1 (`postgres_ffi::PG_TLI`, used by basebackup and safekeepers), and fa504217 ships replica promotion (`compute_promote.rs`). Only touches Neon-specific code that is already on our branch; no ext symbol involved. Prerequisite of "Fix initialization of the WAL buffer at startup". |
| `03980e6c361` | don't force FPI if checksums are enabled | skip-feature | Neon WAL-volume optimisation (redefines `XLogHintBitIsNeeded()`); changes durability semantics, not a fix. Revisit as a product decision if we enable data checksums. |
| `e37678ccde8` | Remove unnecessary set_lwlsn_block_* hooks | skip-ext | Removes `set_lwlsn_block_hook`/`_range_hook`/`_v_hook`, which our pgxn/neon (`neon_lwlsncache.c`) still sets; would not compile. |
| `c79b80990e1` | Change how sorted GiST index build is handled with Neon storage in v14-v16 | skip-ext | Reorders GiST sorted build to WAL-log before `smgrextend()` without the unlogged-build calls; the stated purpose is a pgxn/neon cleanup (reinstate the empty-index check, drop the LFC hack) that our ext lacks. Our ext at fa504217 is built for the current order (check disabled for v14-16); no bug fixed on its own. |
| `8b0823daa48` | Set xl_prev correctly if replica is promoted without replaying any records | pick | Correctness fix in Neon's startup path (`NeonRecoveryRequested`, `neonLastRec`, both on our branch): a replica promoted before replaying any record wrote an end-of-recovery record with a wrong `xl_prev`, breaking replicas and logical replication across the switchover. No ext dependency. |
| `2e2a53729d9` | Fix initialization of the WAL buffer at startup | pick | Correctness fix in Neon's `FinishWalRecovery()` path: wrote past the temp page when end-of-log is page-aligned (assert failure) and copied an uninitialised read buffer into the first WAL page. Needs "Do not create new timeline for replica promotion" first (it rewrites that commit's hunk). |
| `44ae92e105f` | CI: fix GitHub Actions Workflow | skip-feature | Neon's GitHub workflow. |
| `8f9063c9759` | Improve stability of btree page split on ERRORs | pick | Backport of upstream master 85e0ff62b68 (PG 19 only, not back-patched, so no minor brings it). Avoids VACUUM seeing a half-split page as corruption after an ERROR during `_bt_split()`. Same diff as upstream plus an `INJECTION_POINT("bt-split")` (a no-op unless attached). nbtinsert.c only. |
| `5e7285f1ac1` | Move LastWrittenLsnLock to neon extension | skip-ext | Removes the built-in `LastWrittenLsnLock`; our pgxn/neon (`neon_lwlsncache.c`) still uses it; would not compile. |
| `b7509d449cd` | OPtimize storing zero page image in WAL as FPI | skip-feature | FPI-size optimisation that changes the WAL image encoding (hole of BLCKSZ); the Rust WAL decoders at fa504217 were not built for it. Part of the FPI-reduction work. |
| `fb2e4048ff1` | Move NEON_AUTH_TOKEN to a builtin GUC | skip-ext | Part of the walreceiver-auth chain that ends with the GUC moved into a newer neon extension (`neon_storage_token`, absent from our pgxn/neon). |
| `5364e314cc0` | Fix amcheck's handling of incomplete root splits in B-tree | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 15.16. |
| `09142f5a5dc` | Fix amcheck's handling of half-dead B-tree pages | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 15.16. |
| `86aff7992c4` | Move neon_storage_token to PGC_SUSET | skip-ext | `neon_storage_token` GUC chain; moved into the neon extension next, absent from our pgxn/neon. |
| `e4e7cbbfaa8` | Move the neon_storage_token GUC definition to the neon extension | skip-ext | Removes the GUC from core; the definition lives in a newer neon extension that we don't have. |
| `2933c9ec3a9` | Use a hook for getting the walreceiver password | skip-ext | Walreceiver password from a hook set by a newer neon extension (end of the `neon_storage_token` chain). |
| `7ade4e55ccb` | Fix SUBSTRING() for toasted multibyte characters. | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 15.17. |
| `cd0aa6cd15d` | Don't reset 'latest_page_number' when replaying multixid truncation | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 15.17. |
| `ca7a1270203` | [PG_15]Add the ability to reduce FPI (#901) | skip-feature | Databricks (LKB-5974) FPI-reduction feature; changes WAL emission. |
| `c68e989c48e` | Log stop of walreceiver | skip-feature | Diagnostic LOG line only, not a fix. |
| `d63cc94916e` | Correctly handle contrecord in pg_waldump with --ignore option | pick | Fix in Neon's xlogreader `skip_page_validation` path (already on our branch; set only by `pg_waldump --ignore`, used by neon's `test_pg_waldump.py`): skip the continuation record instead of misreading it. Two lines, no server-path change. |
| `08ce83fc980` | Prevent possible search_path attacks | skip-ext | Core side of a superuser search_path hardening: `prohibit_superuser_overrides` is declared here but the GUC is defined in a newer neon extension (absent from our pgxn/neon), so it stays false and the code is inert. Security-relevant: worth our own design later. |
| `3372f2eec95` | Add extension_is_visible_hook for filtering pg_available_extensions (#923) | skip-feature | New hook for a Databricks/Neon extension filter; no consumer in our pgxn/neon. |
| `6056289bb69` | Move extension_is_visible_hook from fmgr.h/fmgr.c to extension.h/extension.c (#934) | skip-feature | Follow-up of the skipped extension_is_visible_hook. |

### Apply order (v15)

1. `67f57716159` Do not create new timeline for replica promotion (#747)
2. `8b0823daa48` Set xl_prev correctly if replica is promoted without replaying any records
3. `2e2a53729d9` Fix initialization of the WAL buffer at startup
4. `8f9063c9759` Improve stability of btree page split on ERRORs
5. `d63cc94916e` Correctly handle contrecord in pg_waldump with --ignore option

Test-apply on our v15 head merged with `REL_15_19`: all 5 applied cleanly with `git cherry-pick -x`, in this order, and `xlog.o`, `xlogrecovery.o`, `xlogreader.o`, `nbtinsert.o` compiled without warnings.
The first three are one chain: the WAL-buffer fix rewrites the hunk the timeline commit adds to `FinishWalRecovery()`, so keep that order.

## v14 (14.18 → 14.24)

Counts: pick 6, skip-ext 11, skip-feature 10, skip-upstream 4, total 31.

| sha | subject | class | reason |
|---|---|---|---|
| `f31add2cb8e` | Initialize the neon storage manager later at backend startup | skip-ext | Moves `smgrinit()` after `InitProcess()` for a newer neon extension (new communicator) that needs `MyProc`; our pgxn/neon explicitly copes with v14 calling it before `MyProc` (`pagestore_smgr.c`, `communicator.c`). |
| `3628a0b46f3` | Refactor SLRU download interface between Postgres and the neon extension | skip-ext | Replaces `f_smgr.smgr_read_slru_segment` with `read_slru_segment_hook` and drops `neon_use_communicator_worker`; our pgxn/neon still uses the old smgr callback (`pagestore_smgr.c`), so it would not compile. |
| `185fb6f3add` | CI: Only test Postgres branch. (#726) | skip-feature | Neon's GitHub workflow; our CI is our own. |
| `d61583aeebc` | WALRecevier read password from env var (#40) | skip-feature | Databricks auth (`NEON_AUTH_TOKEN` env var for the walreceiver); start of a chain that ends in an ext-side hook. |
| `96c49f01200` | [BRC-3414] Add hook for backup token access check on SCHEMAs (#59) | skip-feature | Databricks Unity Catalog (`NamespaceUnityCatalogAccess_hook`); no consumer in our pgxn/neon. |
| `868a293e241` | Add global temp file size limit | skip-ext | Adds `CheckTempFileSize_hook`; the limit itself lives in a newer neon extension (no `CheckTempFileSize` in our pgxn/neon). Inert on its own. |
| `fbf3790134a` | Do not create new timeline for replica promotion (#748) | pick | Neon recovery fix: with `neon.signal` the promoted replica keeps its timeline. Neon storage assumes TLI 1 (`postgres_ffi::PG_TLI`, used by basebackup and safekeepers), and fa504217 ships replica promotion (`compute_promote.rs`). Only touches Neon-specific code that is already on our branch; no ext symbol involved. Prerequisite of "Fix initialization of the WAL buffer at startup". |
| `5061c0662e5` | don't force FPI if checksums are enabled | skip-feature | Neon WAL-volume optimisation (redefines `XLogHintBitIsNeeded()`); changes durability semantics, not a fix. Revisit as a product decision if we enable data checksums. |
| `ff787de4515` | Remove unnecessary set_lwlsn_block_* hooks | skip-ext | Removes `set_lwlsn_block_hook`/`_range_hook`/`_v_hook`, which our pgxn/neon (`neon_lwlsncache.c`) still sets; would not compile. |
| `f1da94792b4` | Change how sorted GiST index build is handled with Neon storage in v14-v16 | skip-ext | Reorders GiST sorted build to WAL-log before `smgrextend()` without the unlogged-build calls; the stated purpose is a pgxn/neon cleanup (reinstate the empty-index check, drop the LFC hack) that our ext lacks. Our ext at fa504217 is built for the current order (check disabled for v14-16); no bug fixed on its own. |
| `c1ee687e413` | Fix initialization of the WAL buffer at startup | pick | Correctness fix in Neon's `FinishWalRecovery()` path: wrote past the temp page when end-of-log is page-aligned (assert failure) and copied an uninitialised read buffer into the first WAL page. Needs "Do not create new timeline for replica promotion" first (it rewrites that commit's hunk). |
| `88e17d723d9` | CI: fix GitHub Actions Workflow | skip-feature | Neon's GitHub workflow. |
| `4bcd6475775` | Improve stability of btree page split on ERRORs | pick | Backport of upstream master 85e0ff62b68 (PG 19 only, not back-patched, so no minor brings it). Avoids VACUUM seeing a half-split page as corruption after an ERROR during `_bt_split()`. Same diff as upstream plus an `INJECTION_POINT("bt-split")` (a no-op unless attached). nbtinsert.c only. |
| `6080526818d` | Move LastWrittenLsnLock to neon extension | skip-ext | Removes the built-in `LastWrittenLsnLock`; our pgxn/neon (`neon_lwlsncache.c`) still uses it; would not compile. |
| `2319943ec40` | OPtimize storing zero page image in WAL as FPI | skip-feature | FPI-size optimisation that changes the WAL image encoding (hole of BLCKSZ); the Rust WAL decoders at fa504217 were not built for it. Part of the FPI-reduction work. |
| `8fa2a498e4c` | Move NEON_AUTH_TOKEN to a builtin GUC | skip-ext | Part of the walreceiver-auth chain that ends with the GUC moved into a newer neon extension (`neon_storage_token`, absent from our pgxn/neon). |
| `b5a942f3acb` | Fix amcheck's handling of incomplete root splits in B-tree | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 14.21. |
| `1d3b0b8f0d0` | Fix amcheck's handling of half-dead B-tree pages | skip-upstream | Upstream back-patch (Heikki Linnakangas, 2025-12-02), same subject/author/date; in 14.21. |
| `0c6577830e9` | Fix incorrect merge in fsm_extend_fix | pick | v14 only: same duplicate `smgrextend()` in Neon's `fsm_extend()` (left by an earlier merge). Self-contained; v15+ never had the duplicate. |
| `a24eebcd2bc` | Remove duplicated smgrextend from vm_extend | pick | v14 only: Neon's `vm_extend()` extends through the buffer manager (`P_NEW`) and then calls `smgrextend()` again for the same block. Self-contained fix in Neon code already on our branch; v15+ never had the duplicate. |
| `858d8341a69` | Move neon_storage_token to PGC_SUSET | skip-ext | `neon_storage_token` GUC chain; moved into the neon extension next, absent from our pgxn/neon. |
| `cc53982b242` | Move the neon_storage_token GUC definition to the neon extension | skip-ext | Removes the GUC from core; the definition lives in a newer neon extension that we don't have. |
| `4c92e75cecf` | Use a hook for getting the walreceiver password | skip-ext | Walreceiver password from a hook set by a newer neon extension (end of the `neon_storage_token` chain). |
| `85b2c2a2597` | Fix SUBSTRING() for toasted multibyte characters. | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 14.22. |
| `ec027b4d7fc` | Don't reset 'latest_page_number' when replaying multixid truncation | skip-upstream | Patch-identical to the upstream commit (`git cherry`); in 14.22. |
| `9f58fa05fd9` | [PG_16]Add the ability to reduce FPI (#900) | skip-feature | Databricks (LKB-5974) FPI-reduction feature; changes WAL emission. |
| `0f91b79947c` | Log stop of walreceiver | skip-feature | Diagnostic LOG line only, not a fix. |
| `937e34e5874` | Correctly handle contrecord in pg_waldump with --ignore option | pick | Fix in Neon's xlogreader `skip_page_validation` path (already on our branch; set only by `pg_waldump --ignore`, used by neon's `test_pg_waldump.py`): skip the continuation record instead of misreading it. Two lines, no server-path change. |
| `e99763f005f` | Prevent possible search_path attacks | skip-ext | Core side of a superuser search_path hardening: `prohibit_superuser_overrides` is declared here but the GUC is defined in a newer neon extension (absent from our pgxn/neon), so it stays false and the code is inert. Security-relevant: worth our own design later. |
| `2f23204d2bc` | Add extension_is_visible_hook for filtering pg_available_extensions (#922) | skip-feature | New hook for a Databricks/Neon extension filter; no consumer in our pgxn/neon. |
| `74c6ea95999` | Move extension_is_visible_hook from fmgr.h/fmgr.c to extension.h/extension.c (#933) | skip-feature | Follow-up of the skipped extension_is_visible_hook. |

### Apply order (v14)

1. `0c6577830e9` Fix incorrect merge in fsm_extend_fix
2. `a24eebcd2bc` Remove duplicated smgrextend from vm_extend
3. `fbf3790134a` Do not create new timeline for replica promotion (#748)
4. `c1ee687e413` Fix initialization of the WAL buffer at startup
5. `4bcd6475775` Improve stability of btree page split on ERRORs
6. `937e34e5874` Correctly handle contrecord in pg_waldump with --ignore option

Test-apply on our v14 head merged with `REL_14_24`: all 6 applied cleanly with `git cherry-pick -x`, in this order, and `xlog.o`, `xlogreader.o`, `nbtinsert.o`, `freespace.o`, `visibilitymap.o` compiled without warnings.
v14 has no "Set xl_prev correctly" commit (that bug is v15+). The WAL-buffer fix rewrites the timeline commit's hunk in `xlog.c`, so keep that order.

## Worth a second look

- **Prevent possible search_path attacks** (`skip-ext`): a security hardening, but in its Neon form it's switched by a GUC (`prohibit_superuser_overrides`) that only a newer neon extension defines. Without that GUC the code is dead. If we want the protection, it should be our own design.
- **Change how sorted GiST index build is handled with Neon storage in v14-v16** (`skip-ext`): applying it looks harmless with our extension (its empty-index check is already disabled for v14-16), but it changes the write order in a Neon storage path for the sake of an extension cleanup we don't have, and it fixes no bug on its own.
- **Do not create new timeline for replica promotion** (`pick`): a behaviour change as well as a fix. It's picked because Neon's storage at `fa504217` assumes timeline 1 (`postgres_ffi::PG_TLI`) and ships replica promotion. The WAL-buffer fix depends on it textually.
- **don't force FPI if checksums are enabled** (`skip-feature`): harmless on Neon storage, but it's an optimisation with different torn-page semantics. It's a product decision for later if we enable data checksums.
