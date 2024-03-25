import Mathlib.MeasureTheory.Measure.GiryMonad
import Mathlib.MeasureTheory.Decomposition.Lebesgue

import SciLean.Core.FunctionPropositions
import SciLean.Core.FunctionSpaces
import SciLean.Core.Integral.CIntegral
import SciLean.Core.Distribution.TestFunction
import SciLean.Core.Distribution.SimpAttr
import SciLean.Util.SorryProof
import SciLean.Util.Limit

open MeasureTheory ENNReal

namespace SciLean

variable
  {R} [RealScalar R]
  {W} [Vec R W] [Module ℝ W]
  {X} [TopologicalSpace X] [space : TCOr (Vec R X) (DiscreteTopology X)]
  {Y} [Vec R Y] [Module ℝ Y]
  {Z} [Vec R Z]

set_default_scalar R

example
    (R : Type u) [RealScalar R]
    (X : Type v) [TopologicalSpace X] [space : TCOr (Vec R X) (DiscreteTopology X)] :
    Vec R (TestFunctionSpace R X) := by infer_instance

variable (R X)
structure Distribution where
  action : (𝒟 X) ⊸ R
variable {R X}

namespace Distribution
scoped notation "⟪" f' ", " φ "⟫" => Distribution.action f' φ
end Distribution

open Distribution

notation "𝒟'" X => Distribution defaultScalar% X

@[app_unexpander Distribution] def unexpandDistribution : Lean.PrettyPrinter.Unexpander
  | `($(_) $_ $X) => `(𝒟' $X)
  | _ => throw ()

@[simp, ftrans_simp]
theorem action_mk_apply (f : (𝒟 X) ⊸ R) (φ : 𝒟 X) :
    ⟪Distribution.mk (R:=R) f, φ⟫ = f φ := by rfl

@[ext]
theorem Distribution.ext (x y : Distribution R X) :
    (∀ (φ : 𝒟 X), ⟪x,φ⟫ = ⟪y,φ⟫)
    →
    x = y := by

  induction x; induction y; simp only [action_mk_apply, mk.injEq]; aesop


----------------------------------------------------------------------------------------------------
-- Algebra -----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

instance : Zero (𝒟' X) := ⟨⟨fun _φ ⊸ 0⟩⟩
instance : Add (𝒟' X) := ⟨fun f g => ⟨fun φ ⊸ ⟪f, φ⟫ + ⟪g, φ⟫⟩⟩
instance : Sub (𝒟' X) := ⟨fun f g => ⟨fun φ ⊸ ⟪f, φ⟫ - ⟪g, φ⟫⟩⟩
instance : Neg (𝒟' X) := ⟨fun f => ⟨fun φ ⊸ -⟪f, φ⟫⟩⟩
instance : SMul R (𝒟' X) := ⟨fun r f => ⟨fun φ ⊸ r • ⟪f, φ⟫⟩⟩

-- not sure what exact the topology is supposed to be here
instance : UniformSpace (𝒟' X) := sorry
instance : Vec R (𝒟' X) := Vec.mkSorryProofs


----------------------------------------------------------------------------------------------------
-- Extended action ---------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

open Notation in
@[pp_dot]
noncomputable
def Distribution.extAction (T : 𝒟' X) (φ : X → R) : R := limit n → ∞, ⟪T, testFunApprox n φ⟫


-- Lean usually fails to unify this theorem, thus we have a custom simproc to apply it
def Distribution.mk_extAction (T : (X → R) → R) (hT : IsSmoothLinearMap R (fun φ : 𝒟 X => T φ)) (φ : X → R) :
   (Distribution.mk (⟨fun φ => T φ,hT⟩)).extAction φ = T φ := sorry_proof

open Lean Meta in
/-- Simproc to apply `Distribution.mk_extAction` theorem -/
simproc_decl Distribution.mk_extAction_simproc (Distribution.extAction (Distribution.mk (SmoothLinearMap.mk _ _)) _) := fun e => do

  let φ := e.appArg!
  let T := e.appFn!.appArg!

  let .lam xName xType xBody xBi := T.appArg!.appFn!.appArg!
    | return .continue
  let hT := T.appArg!.appArg!

  withLocalDecl xName xBi xType fun x => do
  let R := xType.getArg! 0
  let X := xType.getArg! 2
  withLocalDecl `φ' xBi (← mkArrow X R) fun φ' => do
    let b := xBody.instantiate1 x
    let b := b.replace (fun e' =>
      if e'.isAppOf ``DFunLike.coe &&
         5 ≤ e'.getAppNumArgs &&
         e'.getArg! 4 == x then
          .some (mkAppN φ' e'.getAppArgs[5:])
      else
        .none)

    if b.containsFVar x.fvarId! then
      return .continue

    let T ← mkLambdaFVars #[φ'] b
    let prf ← mkAppM ``Distribution.mk_extAction #[T, hT, φ]
    return .visit {expr := T.beta #[φ], proof? := prf}



----------------------------------------------------------------------------------------------------
-- Monadic structure -------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- def dirac (x : X) : Distribution X := fun φ => φ x

-- instance : Monad (Distribution R) where
--   pure := fun x => ⟨fun φ => φ x⟩
--   bind := fun x f => ⟨fun φ => ⟪x, fun x' => ⟪(f x'), φ⟫⟫⟩

-- instance : LawfulMonad (Distribution R) where
--   bind_pure_comp := by intros; rfl
--   bind_map       := by intros; rfl
--   pure_bind      := by intros; rfl
--   bind_assoc     := by intros; rfl
--   map_const      := by intros; rfl
--   id_map         := by intros; rfl
--   seqLeft_eq     := by intros; rfl
--   seqRight_eq    := by intros; rfl
--   pure_seq       := by intros; rfl

def dirac (x : X) : 𝒟' X := ⟨fun φ ⊸ φ x⟩

open Notation
noncomputable
def Distribution.bind (x' : 𝒟' X) (f : X → 𝒟' Y) : 𝒟' Y :=
  limit (n : ℕ) → ∞, ⟨⟨fun φ => ⟪x', testFunApprox n fun x => ⟪f x, φ⟫⟫, sorry_proof⟩⟩


----------------------------------------------------------------------------------------------------
-- Basic identities --------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[simp, ftrans_simp]
theorem action_dirac (x : X) (φ : 𝒟 X) : ⟪((dirac x) : 𝒟' X), φ⟫ = φ x := by rfl

@[simp, ftrans_simp]
theorem action_bind (x : 𝒟' X) (f : X → 𝒟' Y) (φ : 𝒟 Y) :
    ⟪x.bind f, φ⟫ = x.extAction (fun x' => ⟪f x', φ⟫) := by
  simp[Distribution.bind]
  sorry_proof


----------------------------------------------------------------------------------------------------
-- Arithmetics -------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[simp, ftrans_simp, action_push]
theorem Distribution.zero_action (φ : 𝒟 X) : ⟪(0 : 𝒟' X), φ⟫ = 0 := by rfl

@[action_push]
theorem Distribution.add_action (T T' : 𝒟' X) (φ : 𝒟 X) : ⟪T + T', φ⟫ = ⟪T,φ⟫ + ⟪T',φ⟫ := by rfl

@[action_push]
theorem Distribution.sub_action (T T' : 𝒟' X) (φ : 𝒟 X) : ⟪T - T', φ⟫ = ⟪T,φ⟫ - ⟪T',φ⟫ := by rfl

@[action_push]
theorem Distribution.smul_action (r : R) (T : 𝒟' X) (φ : 𝒟 X) : ⟪r • T, φ⟫ = r • ⟪T,φ⟫ := by rfl

@[action_push]
theorem Distribution.neg_action (T : 𝒟' X) (φ : 𝒟 X) : ⟪- T, φ⟫ = - ⟪T,φ⟫ := by rfl

@[simp, ftrans_simp, action_push]
theorem Distribution.zero_extAction (φ : X → R) : (0 : 𝒟' X).extAction φ = 0 := by sorry_proof

-- todo: this needs some integrability condition
@[action_push]
theorem Distribution.add_extAction (T T' : 𝒟' X) (φ : X → R) :
    (T + T').extAction φ = T.extAction φ + T'.extAction φ := by sorry_proof

@[action_push]
theorem Distribution.sub_extAction (T T' : 𝒟' X) (φ : X → R) :
    (T - T').extAction φ = T.extAction φ - T'.extAction φ := by sorry_proof

@[action_push]
theorem Distribution.smul_extAction (r : R) (T : 𝒟' X) (φ : X → R) :
    (r • T).extAction φ = r • T.extAction φ := by sorry_proof

@[action_push]
theorem Distribution.neg_extAction (T : 𝒟' X) (φ : X → R) :
    (- T).extAction φ = - T.extAction φ := by sorry_proof


----------------------------------------------------------------------------------------------------
-- Functions as distributions ----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

variable [MeasureSpace X]

@[coe]
noncomputable
def _root_.Function.toDistribution (f : X → R) : 𝒟' X :=
  ⟨fun φ ⊸ ∫' x, f x • φ x⟩

def Distribution.IsFunction (T : 𝒟' X) : Prop :=
  ∃ (f : X → R), ∀ (φ : 𝒟 X),
      ⟪T, φ⟫ = ∫' x, f x • φ x

open Classical
noncomputable
def Distribution.toFunction (T : 𝒟' X) : X → R :=
  if h : T.IsFunction then
    choose h
  else
    0

@[action_push]
theorem Function.toDistribution_action (f : X → R) (φ : 𝒟 X) :
    ⟪f.toDistribution, φ⟫ = ∫' x, f x * φ x := by rfl

@[action_push]
theorem Function.toDistribution_extAction (f : X → R) (φ : X → R) :
    f.toDistribution.extAction φ
    =
    ∫' x, f x * φ x := sorry_proof


----------------------------------------------------------------------------------------------------
-- Distributional if statement ---------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

open Classical Notation in
noncomputable
def iteD (A : Set X) (t e : 𝒟' X) : 𝒟' X :=
  limit n → ∞,
  ⟨⟨fun φ =>
    ⟪t, testFunApprox n fun x => if x ∈ A then φ x else 0⟫ +
    ⟪e, testFunApprox n fun x => if x ∉ A then φ x else 0⟫, sorry_proof⟩⟩

open Lean.Parser Term in
syntax withPosition("ifD " term " then "
    ppDedent(ppLine ppSpace ppSpace) term ppDedent(ppLine)
  "else"
    ppDedent(ppLine ppSpace ppSpace) term) : term

macro_rules
  | `(ifD $A then $t else $e) => `(iteD $A $t $e)

open Lean Parser in
@[app_unexpander iteD]
def unexpandIteD : Lean.PrettyPrinter.Unexpander
  | `($(_) $A $t $e) => `(ifD $A then $t else $e)
  | _ => throw ()

@[action_push]
theorem Distribution.action_iteD (A : Set X) (t e : 𝒟' X) (φ : 𝒟 X) :
    ⟪iteD A t e, φ⟫ =
        t.extAction (fun x => if x ∈ A then φ x else 0) +
        e.extAction (fun x => if x ∉ A then φ x else 0) := by sorry_proof

@[action_push]
theorem Distribution.extAction_iteD (A : Set X) (t e : 𝒟' X) (φ : X → R) :
    (iteD A t e).extAction φ =
        t.extAction (fun x => if x ∈ A then φ x else 0) +
        e.extAction (fun x => if x ∉ A then φ x else 0) := by sorry_proof


----------------------------------------------------------------------------------------------------
-- Measures as distributions -----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- open Classical in
variable [MeasurableSpace X]
@[coe]
noncomputable
def _root_.MeasureTheory.Measure.toDistribution
    (μ : Measure X) : 𝒟' X :=
  ⟨fun φ ⊸ ∫' x, φ x ∂μ⟩

noncomputable
instance : Coe (Measure X) (𝒟' X) := ⟨fun μ => μ.toDistribution⟩

def Distribution.IsMeasure (f : 𝒟' X) : Prop :=
  ∃ (μ : Measure X), ∀ (φ : 𝒟 X),
      ⟪f, φ⟫ = ∫' x, φ x ∂μ

open Classical
noncomputable
def Distribution.toMeasure (f' : 𝒟' X) : Measure X :=
  if h : f'.IsMeasure then
    choose h
  else
    0

-- @[simp]
-- theorem apply_measure_as_distribution  {X} [MeasurableSpace X]  (μ : Measure X) (φ : X → Y) :
--      ⟪μ.toDistribution, φ⟫ = ∫ x, φ x ∂μ := by rfl

/- under what conditions is this true??? -/
-- theorem action_is_integral  {X} [MeasurableSpace X] {Y} [MeasurableSpace Y]
--     (x : Measure X) (f : X → Measure Y)
--     (φ : Y → Z) (hφ : ∀ x, Integrable φ (f x)) :
--     ⟪x.toDistribution >>= (fun x => (f x).toDistribution), φ⟫
--     =
--     ∫ y, φ y ∂(@Measure.bind _ _ _ _ x f) := by
--   sorry_proof

-- def Distribution.densitvy {X} [MeasurableSpace X] (x y : 𝒟' X) : X → ℝ≥0∞ :=
--   x.toMeasure.rnDeriv y.toMeasure
