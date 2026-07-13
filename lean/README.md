# Lean mechanisation

`MetadataLayout.lean` mechanises a deliberately small core of the paper model:

- statically laid-out base types;
- `str`;
- recursively metadata-sized arrays and slices;
- abstract custom metadata-sized types with checked-soundness and
  checked/unchecked-agreement obligations;
- `TypeLayoutOK`, `SafeMeta`, checked layout, and unchecked layout;
- Proposition 1 (`checked_layout_sound`); and
- Proposition 2 (`unchecked_agreement`).

It does not mechanise structure/union field placement, trait-object provenance,
allocation, initialization, or full Rust reference validity.

With Lean installed, run:

```sh
lake build
```

or directly:

```sh
lean MetadataLayout.lean
```

The supplied source was checked with Lean 4.31.0. The checker exited with code
0 and emitted no diagnostics. The file contains no `sorry`, `admit`, or `axiom`
declarations.

The custom checked-soundness obligation is represented by making
`Env.customChecked` return a subtype containing both a layout and its
`TypeLayoutOK` proof. `Env.customSafeAgreement` represents the custom
safe-metadata agreement assumption used by Proposition 2.
