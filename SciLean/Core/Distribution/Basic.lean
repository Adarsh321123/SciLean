import Mathlib.MeasureTheory.Measure.GiryMonad
import Mathlib.MeasureTheory.Decomposition.Lebesgue

import SciLean.Core.FunctionPropositions
import SciLean.Core.Integral.CIntegral
import SciLean.Util.SorryProof

open MeasureTheory ENNReal

namespace SciLean

local notation "∞" => (⊤ : ℕ∞)

variable
  {R} [RealScalar R]
  {W} [Vec R W] [Module ℝ W]-- [NormedAddCommGroup W] [NormedSpace ℝ W] [CompleteSpace W]
  {X} [Vec R X] -- [NormedAddCommGroup X] [NormedSpace ℝ X] [CompleteSpace X]
  {Y} [Vec R Y] [Module ℝ Y] -- [NormedAddCommGroup Y] [NormedSpace ℝ Y] [CompleteSpace Y]
  {Z} [Vec R Z] -- [NormedAddCommGroup Z] [NormedSpace ℝ Z] [CompleteSpace Z]


/-- Generalized function with domain `X`
todo: consider renaming it to GeneralizedFunction X. -/
structure Distribution (R : Type u) [RealScalar R] (X : Type v) where
  action : (X → R) → R

namespace Distribution
scoped notation "⟪" f' ", " φ "⟫" => Distribution.action f' φ
end Distribution

open Distribution

notation "𝒟'" X => Distribution defaultScalar% X

@[app_unexpander Distribution] def unexpandDistribution : Lean.PrettyPrinter.Unexpander
  | `($(_) $_ $X) => `(𝒟' $X)
  | _ => throw ()

set_default_scalar R

@[simp]
theorem action_mk_apply (f : (X → R) → R) (φ : X → R) :
    ⟪Distribution.mk (R:=R) f, φ⟫ = f φ := by rfl


@[ext]
theorem Distribution.ext (x y : Distribution R X) :
    (∀ (φ : X → R), ⟪x,φ⟫ = ⟪y,φ⟫)
    →
    x = y := by

  induction x; induction y; simp only [action_mk_apply, mk.injEq]
  intro h; funext; tauto


----------------------------------------------------------------------------------------------------
-- Monadic structure -------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- def dirac (x : X) : Distribution X := fun φ => φ x

instance : Monad (Distribution R) where
  pure := fun x => ⟨fun φ => φ x⟩
  bind := fun x f => ⟨fun φ => ⟪x, fun x' => ⟪(f x'), φ⟫⟫⟩


instance : LawfulMonad (Distribution R) where
  bind_pure_comp := by intros; rfl
  bind_map       := by intros; rfl
  pure_bind      := by intros; rfl
  bind_assoc     := by intros; rfl
  map_const      := by intros; rfl
  id_map         := by intros; rfl
  seqLeft_eq     := by intros; rfl
  seqRight_eq    := by intros; rfl
  pure_seq       := by intros; rfl


----------------------------------------------------------------------------------------------------
-- Basic identities --------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[simp, ftrans_simp]
theorem action_pure (x : X) (φ : X → R) : ⟪((pure x) : 𝒟' X), φ⟫ = φ x := by rfl

@[simp, ftrans_simp]
theorem action_bind (x : 𝒟' X) (f : X → 𝒟' Y) (φ : Y → R) :
    ⟪x >>= f, φ⟫ = ⟪x, fun x' => ⟪f x', φ⟫⟫ := by rfl



----------------------------------------------------------------------------------------------------
-- Arithmetics -------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

instance : Zero (Distribution R X) := ⟨⟨fun _φ => 0⟩⟩
instance : Add (Distribution R X) := ⟨fun f g => ⟨fun φ => ⟪f, φ⟫ + ⟪g, φ⟫⟩⟩
instance : Sub (Distribution R X) := ⟨fun f g => ⟨fun φ => ⟪f, φ⟫ - ⟪g, φ⟫⟩⟩
instance : SMul R (Distribution R X) := ⟨fun r f => ⟨fun φ => r • ⟪f, φ⟫⟩⟩


----------------------------------------------------------------------------------------------------
-- Degree ------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- TODO: Move somewhere
class TCOr (A B : Sort _) where
  val : PSum A B

set_option checkBinderAnnotations false in
instance {A B} [inst : A] : TCOr A B where
  val := .inl inst

set_option checkBinderAnnotations false in
instance {A B} [inst : B] : TCOr A B where
  val := .inr inst


-- TODO: refine the notion of distribution degree
--       It should include differentiability, support and integrability
open Classical in
noncomputable
def Distribution.restrictDeg {X} [TopologicalSpace X] [space : TCOr (Vec R X) (DiscreteTopology X)]
    (deg : ℕ∞) (T : 𝒟' X) : 𝒟' X :=
  ⟨fun φ =>
    match space.val with
    | .inl _ =>
      if _ : ContCDiff R deg φ then
        ⟪T, φ⟫
      else
        0
    | .inr _ => ⟪T,φ⟫⟩


@[simp, ftrans_simp]
theorem restrictDeg_restrictDeg (deg deg' : ℕ∞) (T : 𝒟' X) :
    (T.restrictDeg deg).restrictDeg deg' = T.restrictDeg (deg ⊔ deg') := sorry_proof

@[simp, ftrans_simp]
theorem action_restricDeg (deg : ℕ∞) (T : 𝒟' X) (φ : X → R) (hφ : ContCDiff R deg φ) :
    ⟪T.restrictDeg deg, φ⟫ = ⟪T, φ⟫ := by
  unfold restrictDeg
  simp; tauto

@[simp, ftrans_simp]
theorem action_restricDeg' (deg : ℕ∞) (T : 𝒟' X) (φ : X → R) (hφ : ¬(ContCDiff R deg φ)) :
    ⟪T.restrictDeg deg, φ⟫ = 0 := by
  unfold restrictDeg
  simp; tauto


----------------------------------------------------------------------------------------------------
-- Functions as distributions -----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[coe]
noncomputable
def _root_.Function.toDistribution {X} [MeasureSpace X] (f : X → R) : 𝒟' X :=
  ⟨fun φ => ∫' x, f x • φ x⟩

def Distribution.IsFunction {X} [MeasureSpace X] (T : 𝒟' X) : Prop :=
  ∃ (f : X → R), ∀ (φ : X → R),
      ⟪T, φ⟫ = ∫' x, f x • φ x

open Classical
noncomputable
def Distribution.function {X} [MeasureSpace X] (T : 𝒟' X) : X → R :=
  if h : T.IsFunction then
    choose h
  else
    0

-- I do not think that this multiplication is good enough
-- We should be able to multiply nasty distribution with good enough function
noncomputable
instance {X} [MeasureSpace X] : Mul (𝒟' X) :=
  ⟨fun T S => (fun x => T.function x * S.function x).toDistribution⟩


----------------------------------------------------------------------------------------------------
-- Measures as distributions -----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

-- open Classical in
@[coe]
noncomputable
def _root_.MeasureTheory.Measure.toDistribution {X} {_ : MeasurableSpace X}
    (μ : Measure X) : 𝒟' X :=
  ⟨fun φ => ∫' x, φ x ∂μ⟩

noncomputable
instance {X} [MeasurableSpace X] : Coe (Measure X) (𝒟' X) := ⟨fun μ => μ.toDistribution⟩

-- I'm a bit unsure about this definition
-- For example under what conditions `x.IsMeasure → ∀ x', (f x').IsMeasure → (x >>= f).IsMeasure`
-- I'm a bit affraid that with this definition this might never be true as you can always pick
-- really nasty `φ` to screw up the integral
-- So I think that there has to be some condition on `φ`. Likely they should be required to be test funcions

def Distribution.IsMeasure {X} [MeasurableSpace X] (f : 𝒟' X) : Prop :=
  ∃ (μ : Measure X), ∀ (φ : X → R),
      ⟪f, φ⟫ = ∫' x, φ x ∂μ

open Classical
noncomputable
def Distribution.measure {X} [MeasurableSpace X] (f' : 𝒟' X) : Measure X :=
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

theorem Distribution.density {X} [MeasurableSpace X] (x y : 𝒟' X) : X → ℝ≥0∞ :=
  x.measure.rnDeriv y.measure
