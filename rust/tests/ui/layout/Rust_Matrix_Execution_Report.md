# Rust metadata/layout matrix execution report

## Reproduction identity

- Execution date: 2026-07-15
- Repository: `https://github.com/zachs18/rust`
- Branch: `grad-project`
- Tested commit: `b4f061f801b03ab2633fd7aca9e3e78d9b289e7f`
- Commit date: 2026-04-28 07:33:47 -0500
- Host/target: `x86_64-unknown-linux-gnu`
- Stage-0 compiler: `rustc 1.95.0-beta.1 (ad726b506 2026-03-05)`, LLVM 22.1.0
- Built stage-1 compiler: `rustc 1.97.0-dev`, LLVM 22.1.2
- Original uploaded matrix SHA-256: `1e698dfa443de7aea0850abe7e15314ea22c4bd4d20dfae7f35e079cdbe0fc4f`

The uploaded matrix was copied to
`tests/ui/layout/metadata-layout-matrix.rs`. The repository test copy adds only
`dead_code` to the crate-level `allow` list, because compiletest otherwise
rejects two harmless unused-field warnings before reporting the executable
result. No assertion, expected value, type, metadata value, or query was
changed.

The ordinary test command was:

```sh
./x test -j 4 tests/ui/layout/metadata-layout-matrix.rs
```

In the managed execution environment, `CARGO_HOME` was redirected to a
writable directory. A bootstrap-only compatibility adjustment was also needed
because the environment rewrote a symbolic link inside the downloaded CI LLVM
archive. This adjustment restored the LLVM SONAME and shared-library lookup;
it did not modify the compiler or standard-library semantics under test.

## Overall result

**The 13-row run-pass matrix did not pass in full.**

The official compiletest run compiled the test successfully, executed it, and
then exited with status 101 at M5. Rows M1--M4 executed successfully before
that failure. A separate diagnostic execution moved M5 after the remaining
valid rows and retained all their original assertions; it confirmed that
M6--M13 also pass. The diagnostic version replaced only M5's aborting
assertions with observation/printing so that every checked result in that row
could be recorded.

| Matrix rows | Result | Evidence |
|---|---|---|
| M1 | PASS | All six size/alignment/layout queries agree for `u32`: size 4, alignment 4. |
| M2--M4 | PASS | String and slice ordinary/boundary assertions all completed. |
| M5 | **FAIL** | Public checked wrappers reject, but some direct `MetaSized` checked methods accept the same invalid metadata. |
| M6--M8 | PASS | All recursive array/slice metadata assertions completed. |
| M9--M10 | PASS | Aggregate layout and offset/padding assertions completed. |
| M11 | PASS | Trait-object coercion preserved size 4 and alignment 4. |
| M12--M13 | PASS | Custom `FixedTwo` and recursive custom-stride assertions completed. |

No row was skipped. Unchecked queries were not invoked for M5.

## M5 failure details

The intended M5 oracle is that all fallible checked operations reject
unrepresentable metadata. The observed values were:

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

## Interpretation

This is a checked-query coherence defect in the prototype, or alternatively a
contract mismatch that must be resolved explicitly. The public intrinsic
wrappers enforce the target's representable-object bound, whereas the
compiler-generated `MetaSized` methods do not propagate the same validity
decision in every size/alignment/layout path.

The current trait documentation says that the checked methods return `None`
when metadata cannot represent a valid value, so the matrix's rejection oracle
is consistent with the documented contract. The relevant compiler paths for a
future repair include the generated `LayoutForMetaShim` and its separate
size/alignment/layout goals.

Until this inconsistency is fixed or the specification is deliberately
changed, the paper must not report the executable matrix as a complete pass.
It can instead report that the matrix validated M1--M4 and M6--M13 and exposed
the M5 checked-query coherence defect. After a compiler fix, rerun the original
run-pass file and require the compiletest summary to report `1 passed; 0
failed`.

## Diagnostic output

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

