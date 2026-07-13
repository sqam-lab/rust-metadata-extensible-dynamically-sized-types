/-!
A machine-checked core of the paper's metadata/layout model.

Scope: statically laid-out base types, `str`, recursively metadata-sized
arrays and slices, and abstract custom metadata-sized types.  Aggregate field
placement, unions, trait-object provenance, allocation, and initialization are
outside this small mechanisation.
-/

namespace MetadataLayout

/-- A padded object layout. -/
structure Layout where
  size : Nat
  align : Nat
deriving DecidableEq, Repr

/-- `a` is a positive power of two. -/
def IsPowerOfTwo (a : Nat) : Prop := ∃ k : Nat, a = 2 ^ k

/--
Validity of a padded *type* layout.  The divisibility clause is equivalent to
the paper's `size % align = 0` because alignment is positive.
-/
def TypeLayoutOK (maxSize : Nat) (l : Layout) : Prop :=
  0 < l.align ∧
  IsPowerOfTwo l.align ∧
  l.size ≤ maxSize ∧
  ∃ k : Nat, l.size = k * l.align

/-- Type forms in the mechanised core. -/
inductive Ty where
  | base (id : Nat)
  | str
  | array (length : Nat) (element : Ty)
  | slice (element : Ty)
  | custom (id : Nat)
deriving DecidableEq, Repr

/-- Metadata forms corresponding to `Ty`. -/
inductive Meta where
  | unit
  | len (length : Nat)
  | array (element : Meta)
  | slice (length : Nat) (element : Meta)
  | custom (payload : Nat)
deriving DecidableEq, Repr

/--
The target and declaration environment.  The last two fields are precisely
the custom-type assumptions used by Propositions 1 and 2.
-/
structure Env where
  maxSize : Nat
  baseLayout : Nat → Layout
  baseLayoutOK : ∀ id, TypeLayoutOK maxSize (baseLayout id)
  /-- Custom checked layouts carry the custom checked-soundness obligation. -/
  customChecked : Nat → Nat → Option { l : Layout // TypeLayoutOK maxSize l }
  customUnchecked : Nat → Nat → Layout
  customSafe : Nat → Nat → Prop
  customSafeAgreement :
    ∀ id payload,
      customSafe id payload →
        ∃ valid, customChecked id payload = some valid ∧
                 customUnchecked id payload = valid.val

/-- A layout paired with a proof of its validity. -/
def ValidLayout (E : Env) := { l : Layout // TypeLayoutOK E.maxSize l }

private theorem scaledLayoutOK
    {M n : Nat} {l : Layout}
    (hl : TypeLayoutOK M l)
    (hbound : n * l.size ≤ M) :
    TypeLayoutOK M { size := n * l.size, align := l.align } := by
  rcases hl with ⟨halign, hpow, _hsize, k, hk⟩
  refine ⟨halign, hpow, hbound, n * k, ?_⟩
  calc
    n * l.size = n * (k * l.align) := by rw [hk]
    _ = (n * k) * l.align := by simp [Nat.mul_assoc]

private theorem stringLayoutOK {M n : Nat} (h : n ≤ M) :
    TypeLayoutOK M { size := n, align := 1 } := by
  unfold TypeLayoutOK IsPowerOfTwo
  dsimp
  exact ⟨Nat.zero_lt_succ 0, ⟨0, by simp⟩, h, n, by simp⟩

/-- Executable checked layout.  Every successful result carries Proposition 1. -/
def checkedLayout (E : Env) : Ty → Meta → Option (ValidLayout E)
  | .base id, .unit => some ⟨E.baseLayout id, E.baseLayoutOK id⟩
  | .str, .len n =>
      if h : n ≤ E.maxSize then
        some ⟨{ size := n, align := 1 }, stringLayoutOK h⟩
      else
        none
  | .array n element, .array elementMeta =>
      match checkedLayout E element elementMeta with
      | none => none
      | some child =>
          if h : n * child.val.size ≤ E.maxSize then
            some ⟨
              { size := n * child.val.size, align := child.val.align },
              scaledLayoutOK child.property h
            ⟩
          else
            none
  | .slice element, .slice n elementMeta =>
      match checkedLayout E element elementMeta with
      | none => none
      | some child =>
          if h : n * child.val.size ≤ E.maxSize then
            some ⟨
              { size := n * child.val.size, align := child.val.align },
              scaledLayoutOK child.property h
            ⟩
          else
            none
  | .custom id, .custom payload => E.customChecked id payload
  | _, _ => none

/-- The externally visible checked result, with proof data erased. -/
def checkedLayoutRaw (E : Env) (t : Ty) (m : Meta) : Option Layout :=
  match checkedLayout E t m with
  | none => none
  | some valid => some valid.val

/--
Unchecked layout uses the same structural equations but omits representability
checks.  `Option` represents metadata-shape mismatch, not arithmetic failure.
-/
def uncheckedLayout (E : Env) : Ty → Meta → Option Layout
  | .base id, .unit => some (E.baseLayout id)
  | .str, .len n => some { size := n, align := 1 }
  | .array n element, .array elementMeta =>
      match uncheckedLayout E element elementMeta with
      | none => none
      | some child => some { size := n * child.size, align := child.align }
  | .slice element, .slice n elementMeta =>
      match uncheckedLayout E element elementMeta with
      | none => none
      | some child => some { size := n * child.size, align := child.align }
  | .custom id, .custom payload => some (E.customUnchecked id payload)
  | _, _ => none

/--
Reference-safe metadata.  Array and slice rules require safe child metadata
and successful checked aggregate layout, matching the corrected paper rule.
-/
inductive SafeMeta (E : Env) : Ty → Meta → Prop where
  | base (id : Nat) : SafeMeta E (.base id) .unit
  | str (n : Nat) (h : n ≤ E.maxSize) : SafeMeta E .str (.len n)
  | array (n : Nat) {element : Ty} {elementMeta : Meta}
      (child : SafeMeta E element elementMeta)
      (whole : (checkedLayout E (.array n element) (.array elementMeta)).isSome) :
      SafeMeta E (.array n element) (.array elementMeta)
  | slice (n : Nat) {element : Ty} {elementMeta : Meta}
      (child : SafeMeta E element elementMeta)
      (whole : (checkedLayout E (.slice element) (.slice n elementMeta)).isSome) :
      SafeMeta E (.slice element) (.slice n elementMeta)
  | custom (id payload : Nat) (h : E.customSafe id payload) :
      SafeMeta E (.custom id) (.custom payload)

/-- Proposition 1: every successful checked layout is a valid padded layout. -/
theorem checked_layout_sound
    (E : Env) {t : Ty} {m : Meta} {l : Layout}
    (h : checkedLayoutRaw E t m = some l) :
    TypeLayoutOK E.maxSize l := by
  unfold checkedLayoutRaw at h
  cases hc : checkedLayout E t m with
  | none =>
      simp only [hc] at h
      cases h
  | some valid =>
      simp only [hc] at h
      cases h
      exact valid.property

/-- A helper exposing the checked result promised by safe metadata. -/
theorem safe_checked_exists
    (E : Env) {t : Ty} {m : Meta}
    (h : SafeMeta E t m) :
    (checkedLayout E t m).isSome := by
  cases h with
  | base id => simp [checkedLayout]
  | str n hn => simp [checkedLayout, hn]
  | array n child whole => exact whole
  | slice n child whole => exact whole
  | custom id payload hs =>
      rcases E.customSafeAgreement id payload hs with ⟨valid, hchecked, _⟩
      have hc : checkedLayout E (.custom id) (.custom payload) = some valid := hchecked
      rw [hc]
      rfl

/--
Core of Proposition 2: on safe metadata, the unchecked equations return the
same layout as a successful checked computation.
-/
theorem safe_unchecked_eq_checked
    (E : Env) {t : Ty} {m : Meta}
    (hsafe : SafeMeta E t m) {v : ValidLayout E}
    (hchecked : checkedLayout E t m = some v) :
    uncheckedLayout E t m = some v.val := by
  induction hsafe generalizing v with
  | base id =>
      simp [checkedLayout] at hchecked
      cases hchecked
      simp [uncheckedLayout]
  | str n hn =>
      simp [checkedLayout, hn] at hchecked
      cases hchecked
      simp [uncheckedLayout]
  | @array n element elementMeta child whole ih =>
      cases hc : checkedLayout E element elementMeta with
      | none =>
          simp only [checkedLayout, hc] at hchecked
          cases hchecked
      | some childLayout =>
          by_cases hb : n * childLayout.val.size ≤ E.maxSize
          · simp only [checkedLayout, hc, hb, dite_true] at hchecked
            have hv :
                (⟨
                  { size := n * childLayout.val.size, align := childLayout.val.align },
                  scaledLayoutOK childLayout.property hb
                ⟩ : ValidLayout E) = v := Option.some.inj hchecked
            have hvVal := congrArg Subtype.val hv
            have hu := ih hc
            simp only [uncheckedLayout, hu]
            exact congrArg some hvVal
          · simp only [checkedLayout, hc, hb, dite_false] at hchecked
            cases hchecked
  | @slice n element elementMeta child whole ih =>
      cases hc : checkedLayout E element elementMeta with
      | none =>
          simp only [checkedLayout, hc] at hchecked
          cases hchecked
      | some childLayout =>
          by_cases hb : n * childLayout.val.size ≤ E.maxSize
          · simp only [checkedLayout, hc, hb, dite_true] at hchecked
            have hv :
                (⟨
                  { size := n * childLayout.val.size, align := childLayout.val.align },
                  scaledLayoutOK childLayout.property hb
                ⟩ : ValidLayout E) = v := Option.some.inj hchecked
            have hvVal := congrArg Subtype.val hv
            have hu := ih hc
            simp only [uncheckedLayout, hu]
            exact congrArg some hvVal
          · simp only [checkedLayout, hc, hb, dite_false] at hchecked
            cases hchecked
  | custom id payload hs =>
      rcases E.customSafeAgreement id payload hs with ⟨valid, hc, hu⟩
      have hcv : checkedLayout E (.custom id) (.custom payload) = some valid := hc
      have hv : valid = v := Option.some.inj (hcv.symm.trans hchecked)
      have hvVal := congrArg Subtype.val hv
      simp only [uncheckedLayout, hu]
      exact congrArg some hvVal

/-- Proposition 2 in the paper's raw-layout form. -/
theorem unchecked_agreement
    (E : Env) {t : Ty} {m : Meta} {l : Layout}
    (hsafe : SafeMeta E t m)
    (hchecked : checkedLayoutRaw E t m = some l) :
    uncheckedLayout E t m = some l := by
  unfold checkedLayoutRaw at hchecked
  cases hc : checkedLayout E t m with
  | none =>
      simp only [hc] at hchecked
      cases hchecked
  | some valid =>
      simp only [hc] at hchecked
      cases hchecked
      exact safe_unchecked_eq_checked E hsafe hc

end MetadataLayout
