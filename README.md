# A Metadata-First Design for Extensible Dynamically Sized Types in Rust

# Links
- The compiler and standard-library prototype for extended Rust: [[LINK]](https://github.com/zachs18/rust/tree/grad-project) 
- The chronological performance branch: [[LINK]](https://github.com/zachs18/rust/tree/grad-project-perf)

# Validation matrix and traceability

The matrix is a coverage table, not a requirement to create one source file per
cell. The supplied run-pass file groups related cells into named functions so a
failure points to a particular type form or validity condition.

| ID | Type form | Metadata class | Expected result | Principal oracle | Model connection |
|---|---|---|---|---|---|
| M1 | `u32` | trivial | size 4, align 4 | all six queries agree | base rule; Propositions 1 and 2 |
| M2 | `str` | lengths 0 and 5 | size equals length, align 1 | exact assertion | string rule; Propositions 1 and 2 |
| M3 | `[u32]` | lengths 0 and 10 | sizes 0 and 40, align 4 | exact assertion | slice rule; Propositions 1 and 2 |
| M4 | `[u32]` | largest representable length | successful boundary layout | computed boundary oracle | checked multiplication and target bound |
| M5 | `str`, `[u32]` | `usize::MAX` | public checked wrappers and direct checked methods reject | all six checked operations return `None` for each input; revision-specific results below | partiality and cross-layer coherence |
| M6 | `[[u8]; 2]` | recursive child length 3 | size 6, align 1 | metadata obtained from reference | recursive array metadata |
| M7 | `[[u8]]` | outer length 2, child length 3 | size 6, align 1 | metadata obtained from reference | recursive slice metadata |
| M8 | `[[u8; 3]]` | outer length 2 | size 6, align 1 | metadata obtained from reference | ordinary slice of arrays |
| M9 | `PairOfStrs` | lengths 42 and 37 | size 79, align 1 | aggregate metadata assertion | aggregate checked-layout rule |
| M10 | `OffsetStruct<[[u32]]>` | statically known child alignment | tail offset 4 | `offset_of!` | padding and field-offset consequence |
| M11 | `dyn Debug` from `u32` | valid vtable witness | size 4, align 4 | coercion-created metadata | coercion preservation |
| M12 | custom `FixedTwo` | unique thin metadata | size 2, align 2 | six-method coherence | custom obligations 1, 2, 4, and 6 |
| M13 | `[FixedTwo; 2]`, `[FixedTwo]` | recursive custom metadata | size 4, align 2 | exact assertion | padded stride and recursive safety |

## M5 status by compiler revision

**M5 passes in the later recorded strict runs.** The earlier partial failure
belongs to a different compiler revision.

| Compiler revision | M5 result | Evidence |
|---|---|---|
| [`b4f061f801b0`](https://github.com/zachs18/rust/commit/b4f061f801b03ab2633fd7aca9e3e78d9b289e7f) | Partial failure: public checked wrappers reject, but some direct checked methods accept invalid metadata. | Original 2026-07-15 compiletest and diagnostic runs. |
| [`4a937714ecc5`](https://github.com/zachs18/rust/commit/4a937714ecc575b0c503ee8b8982e538547dfd2b) | Pass: all public and direct checked assertions reject both M5 inputs. | Archived `prototype-confirmation-02` strict matrix: compile exit 0, run exit 0. |
| `4a937714ecc5` plus the separate crash-repair patch | Pass again. | Archived `repaired-clean-20261006` strict matrix: compile exit 0, run exit 0. |

Both later executions completed the full 13-row matrix. M5 calls
`assert_rejected` for `str` and `[u32]` with length `usize::MAX`; each call
asserts `None` from all three public checked operations and all three direct
`MetaSized` checked methods. These are strict assertions, not the separate
diagnostic program that prints the earlier discrepancy.

The source hashes and saved exit records were reconciled on 2026-10-08.
This documentation update did not rerun the compiler. M5 already passed in
the unpatched later revision, so its correction is not attributed to the
separate crash-repair patch. This closes the two tested rejection cases; it
does not establish correctness for all metadata or a full Rust soundness
result.

See the [execution history, source hashes and rerun command](rust/tests/ui/layout/README.md)
and the [strict matrix source](rust/tests/ui/layout/metadata-layout-matrix.rs).
The later raw records are in the journal revision's experiment supplement,
under `results/prototype-confirmation-02/` and
`results/repaired-clean-20261006/`; that supplement is separate from this
repository.

## Pass criterion

The prototype-validation result is a pass only if the entire run-pass test
exits successfully on the documented compiler commit and target. Record:

- repository URL and commit SHA;
- host target triple;
- exact command and execution mode (compiletest or direct compilation and execution);
- the pass/fail summary;
- any skipped rows and the reason.
- source SHA-256 and any local compiler patch.

