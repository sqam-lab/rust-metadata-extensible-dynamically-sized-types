# Rust metadata/layout matrix execution history

## Current status: later strict runs pass

Evidence reconciled on 2026-10-08 shows that the historical M5 partial failure below does not describe the later tested compiler. On compiler commit [`4a937714ecc575b0c503ee8b8982e538547dfd2b`](https://github.com/zachs18/rust/commit/4a937714ecc575b0c503ee8b8982e538547dfd2b), both the unpatched and separately crash-repaired builds compile and execute the strict 13-row matrix successfully on `x86_64-unknown-linux-gnu`.

| Archived run | Compiler state | Compile exit | Run exit | M5 |
|---|---|---:|---:|---|
| `prototype-confirmation-02` | `4a937714ecc5`, without the crash-repair patch | 0 | 0 | All public and direct checked assertions pass. |
| `repaired-clean-20261006` | `4a937714ecc5` plus the documented crash-repair patch | 0 | 0 | All public and direct checked assertions pass. |

In [the strict matrix](metadata-layout-matrix.rs), `main` calls `overflow_is_rejected_without_calling_unchecked`. That function calls `assert_rejected` for `str` and `[u32]`, each with length `usize::MAX`. For each input, the helper asserts `None` from:

- `mem::checked_size_for_meta`;
- `mem::checked_align_for_meta`;
- `Layout::for_meta`;
- `MetaSized::checked_size_for_meta`;
- `MetaSized::checked_align_for_meta`;
- `MetaSized::checked_layout_for_meta`.

The successful exit records therefore cover the direct checked methods as well as the wrappers. The separate diagnostic source that prints M5 values is not the source used for these passing records. No row is skipped in the strict source.

### Later-run traceability

Paths below are relative to the experiment supplement supplied with the journal revision. The supplement contains the compiler pins, patch, source, commands and raw records; it is separate from this repository.

| File | SHA-256 |
|---|---|
| `vendor/metadata-layout-matrix.rs` | `28caefa2c349729da4fe7f64768277f2fbc9b847b7c7599f5e345196ec010af9` |
| `results/prototype-confirmation-02/results.json` | `88d6c0aee2c823c767daa5f5f97beede7cb5ff6d81f6bdc8c4e3cd3bb39eb11a` |
| `results/repaired-clean-20261006/results.json` | `635a536d627357d942accf535a89c229b004e58a9b9fdf94e17209f4ca992957` |

In each results file, the `metadata_layout_matrix` record carries the source hash above and both exit codes. The archived source differs from this repository's source only by two `#[allow(unused)]` annotations on `PairOfStrs` and `OffsetStruct`. Its assertions, inputs and execution order are unchanged.

These later records use direct compilation and execution. They are not a new compiletest summary. To rerun the repository's strict assertions after building stage 1 at the pinned later compiler revision, set the two paths and run:

```sh
compiler_root=/path/to/pinned/compiler
artifact_root=/path/to/rust-metadata-extensible-dynamically-sized-types
stage1="$compiler_root/build/x86_64-unknown-linux-gnu/stage1"

"$stage1/bin/rustc" \
  "$artifact_root/rust/tests/ui/layout/metadata-layout-matrix.rs" \
  --edition=2024 --sysroot "$stage1" \
  -C linker-features=-lld -C opt-level=0 -A warnings \
  --cfg prototype -o ./metadata_layout_matrix.bin &&
./metadata_layout_matrix.bin
```

A successful strict execution exits with status 0 and needs no printed output. The supplement's results retain the original absolute commands for both runs. This rerun command does not itself build the compiler; the supplement supplies the build procedure and environment adjustments.

This documentation update rechecked saved evidence, without rebuilding or rerunning the compiler. The M5 correction is present in the unpatched later revision and is not attributed to the separate crash-repair patch. Passing these two rejection inputs and the other matrix assertions is regression evidence, not a proof of all checked-method behavior or broader soundness.

## Historical report: 2026-07-15

The following observations remain the record for `b4f061f801b03ab2633fd7aca9e3e78d9b289e7f`. They are retained so that the earlier partial failure can be reproduced and distinguished from the later passing runs.

### Historical Reproduction identity

- Execution date: 2026-07-15
- Repository: `https://github.com/zachs18/rust`
- Branch: `grad-project`
- Tested commit: `b4f061f801b03ab2633fd7aca9e3e78d9b289e7f`
- Commit date: 2026-04-28 07:33:47 -0500
- Host/target: `x86_64-unknown-linux-gnu`
- Stage-0 compiler: `rustc 1.95.0-beta.1 (ad726b506 2026-03-05)`, LLVM 22.1.0
- Built stage-1 compiler: `rustc 1.97.0-dev`, LLVM 22.1.2
- Original uploaded matrix SHA-256: `1e698dfa443de7aea0850abe7e15314ea22c4bd4d20dfae7f35e079cdbe0fc4f`

The uploaded matrix was copied to `tests/ui/layout/metadata-layout-matrix.rs`. The repository test copy adds only `dead_code` to the crate-level `allow` list, because compiletest otherwise rejects two harmless unused-field warnings before reporting the executable result. No assertion, expected value, type, metadata value, or query was changed.

The ordinary test command was:

```sh
./x test -j 4 tests/ui/layout/metadata-layout-matrix.rs
```

In the managed execution environment, `CARGO_HOME` was redirected to a writable directory. A bootstrap-only compatibility adjustment was also needed because the environment rewrote a symbolic link inside the downloaded CI LLVM archive. This adjustment restored the LLVM SONAME and shared-library lookup; it did not modify the compiler or standard-library semantics under test.

### Historical Overall result

**The 13-row run-pass matrix did not pass in full.**

The official compiletest run compiled the test successfully, executed it, and then exited with status 101 at M5. Rows M1--M4 executed successfully before that failure. A separate diagnostic execution moved M5 after the remaining valid rows and retained all their original assertions; it confirmed that M6--M13 also pass. The diagnostic version replaced only M5's aborting assertions with observation/printing so that every checked result in that row could be recorded.

| Matrix rows | Result | Evidence |
|---|---|---|
| M1 | PASS | All six size/alignment/layout queries agree for `u32`: size 4, alignment 4. |
| M2--M4 | PASS | String and slice ordinary/boundary assertions all completed. |
| M5 | **PARTIAL** | Public checked wrappers reject as expected; direct `MetaSized` checked methods are not coherent. |
| M6--M8 | PASS | All recursive array/slice metadata assertions completed. |
| M9--M10 | PASS | Aggregate layout and offset/padding assertions completed. |
| M11 | PASS | Trait-object coercion preserved size 4 and alignment 4. |
| M12--M13 | PASS | Custom `FixedTwo` and recursive custom-stride assertions completed. |

No row was skipped. Unchecked queries were not invoked for M5.

### Historical M5 failure details

The intended M5 oracle is that all fallible checked operations reject unrepresentable metadata. The observed values were:

| Type and metadata | `mem::checked_size_for_meta` | `mem::checked_align_for_meta` | `Layout::for_meta` | `MetaSized::checked_size_for_meta` | `MetaSized::checked_align_for_meta` | `MetaSized::checked_layout_for_meta` |
|---|---:|---:|---:|---:|---:|---:|
| `str`, `len = usize::MAX` | `None` | `None` | `None` | `Some(usize::MAX)` | `Some(1)` | `Some((usize::MAX, 1))` |
| `[u32]`, `len = usize::MAX` | `None` | `None` | `None` | `None` | `Some(4)` | `None` |

The first official assertion failure was therefore:

```text
assertion `left == right` failed
  left: Some(18446744073709551615)
 right: None
```

This occurred at the direct call to
`<str as MetaSized>::checked_size_for_meta`, after the three public checked
operations had already returned `None` as expected.

### Interpretation of the historical run

At this historical revision, the result exposed a checked-query coherence defect: public intrinsic wrappers enforce the target's representable-object bound, whereas the compiler-generated `MetaSized` methods did not propagate the same validity decision in every size/alignment/layout path.

The trait documentation for that revision required checked methods return `None` when metadata could not represent a valid value, so the rejection oracle was consistent with the contract. Relevant implementation paths included the generated `LayoutForMetaShim` and its separate size/alignment/layout goals.

The historical run supports M1--M4 and M6--M13, with a partial failure at M5. The later strict runs reported above support a complete pass for their documented compiler state and target, including the unchanged M5 rejection assertions. They are direct compile-and-run results; no replacement compiletest summary is claimed.

## Historical diagnostic output

```text
M1 PASS
M2--M4 PASS
M6--M8 PASS
M9--M10 PASS
M11 PASS
M12--M13 PASS
M5-str-usize-max: mem_size=None, mem_align=None, public_layout=None, trait_size=Some(18446744073709551615), trait_align=Some(1), trait_layout=Some((18446744073709551615, 1))
M5-slice-u32-usize-max: mem_size=None, mem_align=None, public_layout=None, trait_size=None, trait_align=Some(4), trait_layout=None
```

