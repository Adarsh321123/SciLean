import SciLean.Core.Distribution.Basic
import SciLean.Core.FunctionTransformations
import SciLean.Core.FunctionPropositions
import SciLean.Core.Notation


open MeasureTheory

namespace SciLean

open Distribution

variable
  {R} [RealScalar R]
  {W} [Vec R W]
  {X} [Vec R X]
  {Y} [Vec R Y]
  {Z} [Vec R Z] [Module ℝ Z]

set_default_scalar R

noncomputable
def dpure (x dx : X) : 𝒟' X := ⟨fun φ ⊸ cderiv R φ x dx⟩

@[fun_prop]
def DistribDifferentiableAt (f : X → 𝒟' Y) (x : X) :=
  ∀ (φ : X → 𝒟 Y), CDifferentiableAt R φ x → CDifferentiableAt R (fun x => ⟪f x, φ x⟫) x


theorem distribDifferentiableAt_const_test_fun
    {f : X → 𝒟' Y} {x : X}
    (hf : DistribDifferentiableAt f x)
    {φ : 𝒟 Y} :
    CDifferentiableAt R (fun x => ⟪f x, φ⟫) x := by
  apply hf
  fun_prop


@[fun_prop]
def DistribDifferentiable (f : X → 𝒟' Y) :=
  ∀ x, DistribDifferentiableAt f x


open Classical in
@[fun_trans]
noncomputable
def parDistribDeriv (f : X → 𝒟' Y) (x dx : X) : 𝒟' Y :=
  ⟨⟨fun φ =>
    if _ : DistribDifferentiableAt f x then
      ∂ (x':=x;dx), ⟪f x', φ⟫
    else
      0, sorry_proof⟩⟩


----------------------------------------------------------------------------------------------------
-- Const rule --------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem DistribDiffrentiable.const_rule (T : 𝒟' X) :
    DistribDifferentiable (fun _ : W => T) := by
  intro _ φ hφ; simp; fun_prop

@[fun_trans]
theorem parDistribDeriv.const_rule (T : 𝒟' X) :
    parDistribDeriv (fun _ : W => T)
    =
    fun w dw =>
      0 := by
  funext w dw; ext φ
  unfold parDistribDeriv
  fun_trans


----------------------------------------------------------------------------------------------------
-- Pure --------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem dirac.arg_x.DistribDiffrentiable_rule
    (f : X → Y) (hf : CDifferentiable R f) :
    DistribDifferentiable (R:=R) (fun x => dirac (f x))  := by
  intro x
  unfold DistribDifferentiableAt
  intro φ hφ
  simp [action_dirac, dirac]
  fun_prop


@[fun_trans]
theorem Pure.pure.arg_x.parDistribDeriv_rule
    (f : X → Y) (hf : CDifferentiable R f) :
    parDistribDeriv (R:=R) (fun x => dirac (f x))
    =
    fun x dx =>
      let ydy := fwdDeriv R f x dx
      (dpure (R:=R) ydy.1 ydy.2) := by
  funext x dx; ext φ
  unfold parDistribDeriv dpure
  simp [pure, fwdDeriv, DistribDifferentiableAt]
  fun_trans
  . intro φ' hφ' h
    have : CDifferentiableAt R (fun x => (φ' x) (f x)) x := by fun_prop
    contradiction


----------------------------------------------------------------------------------------------------
-- Composition -------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem DistribDiffrentiable.comp_rule
    (f : Y → 𝒟' Z) (g : X → Y)
    (hf : DistribDifferentiable f) (hg : CDifferentiable R g) :
    DistribDifferentiable (fun x => f (g x)) := by
  intro x
  unfold DistribDifferentiableAt
  intro φ hφ
  apply CDifferentiable.comp_rule (K:=R) (f:=fun xy : X×Y => ⟪f xy.2,φ xy.1⟫) (g:=fun x => (x, g x))
    (hg:=by fun_prop)
  intro x
  sorry_proof -- is this even true ?


@[fun_trans]
theorem parDistribDeriv.comp_rule
    (f : Y → 𝒟' Z) (g : X → Y)
    (hf : DistribDifferentiable f) (hg : CDifferentiable R g) :
    parDistribDeriv (fun x => f (g x))
    =
    fun x dx =>
      let ydy := fwdDeriv R g x dx
      parDistribDeriv f ydy.1 ydy.2 := by

  funext x dx; ext φ
  unfvold parDistribDeriv
  simp[hg]
  sorry_proof


----------------------------------------------------------------------------------------------------
-- Bind --------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------


-- The assumptions here are definitely not right!!!
-- I think `f` has to be `deg`
@[fun_prop]
theorem Bind.bind.arg_fx.DistribDifferentiable_rule
    (f : X → Y → 𝒟' Z) (g : X → 𝒟' Y)
    (hf : DistribDifferentiable (fun (x,y) => f x y)) -- `f` has to be nice enough to accomodate action of `g`
    (hg : DistribDifferentiable g) :
    DistribDifferentiable (fun x => (g x).bind (f x)) := by

  intro x
  unfold DistribDifferentiableAt
  intro φ hφ
  simp
  sorry_proof


@[fun_trans]
theorem Bind.bind.arg_fx.parDistribDiff_rule
    (f : X → Y → 𝒟' Z) (g : X → 𝒟' Y)
    (hf : DistribDifferentiable (fun (x,y) => f x y)) -- `f` has to be nice enough to accomodate action of `g`
    (hg : DistribDifferentiable g) :
    parDistribDeriv (fun x => (g x).bind (f x))
    =
    fun x dx =>
      ((parDistribDeriv  g x dx).bind (f x · ))
      +
      ((g x).bind (fun y => parDistribDeriv (f · y) x dx)) := sorry_proof



----------------------------------------------------------------------------------------------------
-- Integral ----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

variable [MeasureSpace X] [MeasureSpace Y] [MeasureSpace (X×Y)]

open Notation

@[fun_trans]
theorem cintegral.arg_f.cderiv_distrib_rule (f : W → X → R) :
    cderiv R (fun w => ∫' x, f w x)
    =
    fun w dw =>
      (parDistribDeriv (fun w => (f w ·).toDistribution) w dw).extAction (fun _ => 1) := sorry_proof


@[fun_trans]
theorem cintegral.arg_f.cderiv_distrib_rule' (f : W → X → R) (A : Set X):
    cderiv R (fun w => ∫' x in A, f w x)
    =
    fun w dw =>
      (ifD A then
         parDistribDeriv (fun w => (f w ·).toDistribution) w dw
       else
         0).extAction fun _ => 1 := sorry_proof



@[fun_trans]
theorem cintegral.arg_f.parDistribDeriv_rule (f : W → X → Y → R) :
    parDistribDeriv (fun w => (fun x => ∫' y, f w x y).toDistribution)
    =
    fun w dw =>
      ⟨⟨fun φ => (parDistribDeriv (fun w => (fun (x,y) => f w x y).toDistribution) w dw).extAction fun (x,_) => φ x, sorry_proof⟩⟩ := sorry_proof


#check Set.pi

@[fun_trans]
theorem cintegral.arg_f.parDistribDeriv_rule' (f : W → X → Y → R) (B : X → Set Y) :
    parDistribDeriv (fun w => (fun x => ∫' y in B x, f w x y).toDistribution)
    =
    fun w dw =>
       ⟨⟨fun φ => (ifD {xy : X×Y | xy.2 ∈ B xy.1} then
                    parDistribDeriv (fun w => (fun (x,y) => f w x y).toDistribution) w dw
                  else
                    0).extAction fun (x,_) => φ x, sorry_proof⟩⟩ := sorry_proof


-- @[fun_trans]
-- theorem cintegral.arg_f.cderiv_distrib_rule' (f : W → X → R) (A : Set X):
--     cderiv R (fun w => ∫' x in A, f w x)
--     =
--     fun w dw =>
--       ⟪ifD A then
--          parDistribDeriv ⊤ (fun w => (f w ·).toDistribution) w dw
--        else
--          0, fun _ => 1⟫ := sorry_proof




----------------------------------------------------------------------------------------------------
-- Add ---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem HAdd.hAdd.arg_a0a1.DistribDifferentiable_rule (f g : W → X → R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    DistribDifferentiable (fun w => (fun x => f w x + g w x).toDistribution) := by
  intro _ φ hφ; simp; sorry_proof -- fun_prop (disch:=assumption)

-- we probably only require local integrability in `x` of f and g for this to be true
@[fun_trans]
theorem HAdd.hAdd.arg_a0a1.parDistribDeriv_rule (f g : W → X → R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    parDistribDeriv (fun w => (fun x => f w x + g w x).toDistribution)
    =
    fun w dw =>
      parDistribDeriv (fun w => (f w ·).toDistribution) w dw
      +
      parDistribDeriv (fun w => (g w ·).toDistribution) w dw := by
  funext w dw; ext φ; simp[parDistribDeriv]
  sorry_proof


----------------------------------------------------------------------------------------------------
-- Sub ---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem HSub.hSub.arg_a0a1.DistribDifferentiable_rule (f g : W → X → R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    DistribDifferentiable (fun w => (fun x => f w x - g w x).toDistribution) := by
  intro _ φ hφ; simp; sorry_proof -- fun_prop (disch:=assumption)


@[fun_trans]
theorem HSub.hSub.arg_a0a1.parDistribDeriv_rule (f g : W → X → R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    parDistribDeriv (fun w => (fun x => f w x - g w x).toDistribution)
    =
    fun w dw =>
      parDistribDeriv (fun w => (f w ·).toDistribution) w dw
      -
      parDistribDeriv (fun w => (g w ·).toDistribution) w dw := by
  funext w dw; ext φ; simp[parDistribDeriv]
  sorry_proof


----------------------------------------------------------------------------------------------------
-- Mul ---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem HMul.hMul.arg_a0a1.DistribDifferentiable_rule (f : W → X → R) (r : R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    DistribDifferentiable (fun w => (fun x => r * f w x).toDistribution) := by
  intro _ φ hφ; simp; sorry_proof -- fun_prop (disch:=assumption)


@[fun_trans]
theorem HMul.hMul.arg_a0a1.parDistribDeriv_rule (f : W → X → R) (r : R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    parDistribDeriv (fun w => (fun x => r * f w x).toDistribution)
    =
    fun w dw =>
      r • (parDistribDeriv (fun w => (f w ·).toDistribution) w dw) := by
  funext w dw; ext φ; simp[parDistribDeriv]
  sorry_proof


----------------------------------------------------------------------------------------------------
-- Div ---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------

@[fun_prop]
theorem HDiv.hDiv.arg_a0a1.DistribDifferentiable_rule (f : W → X → R) (r : R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    DistribDifferentiable (fun w => (fun x => f w x / r).toDistribution) := by
  intro _ φ hφ; simp; sorry_proof -- fun_prop (disch:=assumption)


@[fun_trans]
theorem HDiv.hDiv.arg_a0a1.parDistribDeriv_rule (f : W → X → R) (r : R)
    /- (hf : ∀ x, CDifferentiable R (f · x)) (hg : ∀ x, CDifferentiable R (g · x)) -/ :
    parDistribDeriv (fun w => (fun x => f w x / r).toDistribution)
    =
    fun w dw =>
      r⁻¹ • (parDistribDeriv (fun w => (f w ·).toDistribution) w dw) := by
  funext w dw; ext φ; simp[parDistribDeriv]
  sorry_proof
