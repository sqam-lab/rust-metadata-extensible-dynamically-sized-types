# A Metadata-First Design for Extensible Dynamically Sized Types in Rust

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
| M5 | `str`, `[u32]` | `usize::MAX` | all checked queries reject | `None`; unchecked not called | partiality of checked layout |
| M6 | `[[u8]; 2]` | recursive child length 3 | size 6, align 1 | metadata obtained from reference | recursive array metadata |
| M7 | `[[u8]]` | outer length 2, child length 3 | size 6, align 1 | metadata obtained from reference | recursive slice metadata |
| M8 | `[[u8; 3]]` | outer length 2 | size 6, align 1 | metadata obtained from reference | ordinary slice of arrays |
| M9 | `PairOfStrs` | lengths 42 and 37 | size 79, align 1 | aggregate metadata assertion | aggregate checked-layout rule |
| M10 | `OffsetStruct<[[u32]]>` | statically known child alignment | tail offset 4 | `offset_of!` | padding and field-offset consequence |
| M11 | `dyn Debug` from `u32` | valid vtable witness | size 4, align 4 | coercion-created metadata | coercion preservation |
| M12 | custom `FixedTwo` | unique thin metadata | size 2, align 2 | six-method coherence | custom obligations 1, 2, 4, and 6 |
| M13 | `[FixedTwo; 2]`, `[FixedTwo]` | recursive custom metadata | size 4, align 2 | exact assertion | padded stride and recursive safety |

## Pass criterion

The prototype-validation result is a pass only if the entire run-pass test
exits successfully on the documented compiler commit and target. Record:

- repository URL and commit SHA;
- host target triple;
- exact `./x test` command;
- the pass/fail summary;
- any skipped rows and the reason.

