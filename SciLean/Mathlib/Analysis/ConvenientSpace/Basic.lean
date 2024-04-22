import Mathlib.Algebra.Module.Basic
import Mathlib.Data.RCLike.Lemmas
import Mathlib.Topology.Algebra.Module.LocallyConvex

import SciLean.Util.SorryProof

namespace SciLean


-- TODO: move this section
namespace Curve

variable {K : Type u} [NontriviallyNormedField K]
variable {F : Type v} [AddCommGroup F] [Module K F] [TopologicalSpace F] -- [TopologicalAddGroup F] [ContinuousSMul K F]
variable {E : Type w} [AddCommGroup E] [Module K E] [TopologicalSpace E] -- [TopologicalAddGroup E] [ContinuousSMul K E]

open scoped Classical Topology BigOperators Filter ENNReal

open Filter Asymptotics Set

def HasDerivAtFilter (f : K → F) (f' : F) (x : K) (L : Filter K) :=
  Tendsto (fun x' => (x' - x)⁻¹ • (f x' - f x)) L (nhds f')

def HasDerivAt (f : K → F) (f' : F) (x : K) :=
  HasDerivAtFilter f f' x (𝓝 x)

def DifferentiableAt (f : K → F) (x : K) :=
  ∃ f' : F, HasDerivAt f f' x

noncomputable
def deriv (f : K → F) (x : K) :=
  if h : ∃ f', HasDerivAt f f' x then Classical.choose h else 0

def Differentiable (f : K → F) :=
  ∀ x, DifferentiableAt f x

-- TODO: This should probably be true on small neighborhood of x not just *at* x
def DifferentiableAtN (f : K → F) (x : K) (n : Nat) :=
  match n with
  | 0 => ContinuousAt f x
  | n+1 => DifferentiableAt f x ∧ DifferentiableAtN (deriv f) x n

def DifferentiableN (f : K → F) (n : Nat) := ∀ x, DifferentiableAtN f x n
def SmoothAt        (f : K → F) (x : K)   := ∀ n, DifferentiableAtN f x n
def Smooth          (f : K → F)           := ∀ x n, DifferentiableAtN f x n

end Curve


class ConvenientAddGroup (X : Type _)
  extends
    AddCommGroup X,
    TopologicalSpace X,
    TopologicalAddGroup X


class ConvenientSpace (K : Type _) [RCLike K] (X : Type _) [ConvenientAddGroup X]
  extends
    Module K X,
    ContinuousSMul K X
  where
    -- locally convex in some sense, mathlib definition is odd
    -- mild completeness condition
    scalar_wise_smooth : ∀ (c : K → X),
      Curve.Smooth c
      ↔
      ∀ x' : X →L[K] K, Curve.Smooth (x'∘c)

section CommonVectorSpaces

  -- variable {α β ι : Type u}
  variable {K : Type _} [RCLike K]
  -- variable {U V} [Vec K U] [Vec K V]
  -- variable {E : ι → Type v}

  -- instance {X} [Vec K X] : Inhabited X := ⟨0⟩

  -- instance : MulAction ℝ ℝ := MulAction.mk sorry_proof sorry_proof
  -- instance : DistribMulAction ℝ ℝ := DistribMulAction.mk sorry_proof sorry_proof
  -- instance : Module ℝ ℝ := Module.mk sorry_proof sorry_proof
  -- instance : Vec ℝ := Vec.mk


  abbrev AddSemigroup.mkSorryProofs {α} [Add α] : AddSemigroup α := AddSemigroup.mk sorry_proof
  abbrev AddMonoid.mkSorryProofs {α} [Add α] [Zero α] : AddMonoid α :=
    AddMonoid.mk (toAddSemigroup := AddSemigroup.mkSorryProofs) sorry_proof sorry_proof nsmulRec sorry_proof sorry_proof
  abbrev SubNegMonoid.mkSorryProofs {α} [Add α] [Sub α] [Neg α] [Zero α]  : SubNegMonoid α :=
    SubNegMonoid.mk (toAddMonoid := AddMonoid.mkSorryProofs) sorry_proof zsmulRec sorry_proof sorry_proof sorry_proof
  abbrev AddGroup.mkSorryProofs {α} [Add α] [Sub α] [Neg α] [Zero α] : AddGroup α :=
    AddGroup.mk (toSubNegMonoid := SubNegMonoid.mkSorryProofs) sorry_proof
  abbrev AddCommGroup.mkSorryProofs {α} [Add α] [Sub α] [Neg α] [Zero α] : AddCommGroup α :=
    AddCommGroup.mk (toAddGroup := AddGroup.mkSorryProofs) sorry_proof

  abbrev MulAction.mkSorryProofs {α β} [Monoid α] [SMul α β] : MulAction α β := MulAction.mk sorry_proof sorry_proof
  abbrev DistribMulAction.mkSorryProofs {α β} [Monoid α] [AddMonoid β] [SMul α β] : DistribMulAction α β :=
    DistribMulAction.mk (toMulAction := MulAction.mkSorryProofs) sorry_proof sorry_proof
  abbrev Module.mkSorryProofs {α β} [Semiring α] [addcommgroup : AddCommGroup β] [SMul α β] : Module α β :=
    Module.mk (toDistribMulAction := DistribMulAction.mkSorryProofs) sorry_proof sorry_proof

  abbrev ContinuousAdd.mkSorryProofs {α} [Add α] [TopologicalSpace α] : ContinuousAdd α := ContinuousAdd.mk sorry_proof
  abbrev ContinuousNeg.mkSorryProofs {α} [Neg α] [TopologicalSpace α] : ContinuousNeg α := ContinuousNeg.mk sorry_proof
  abbrev TopologicalAddGroup.mkSorryProofs {α} [Add α] [Sub α] [Neg α] [Zero α] [TopologicalSpace α] :=
   @TopologicalAddGroup.mk α _ (AddGroup.mkSorryProofs) (ContinuousAdd.mkSorryProofs) (ContinuousNeg.mkSorryProofs)

  abbrev ConvenientAddGroup.mkSorryProofs {α} [Add α] [Sub α] [Neg α] [Zero α] [TopologicalSpace α] :
      ConvenientAddGroup α :=
    @ConvenientAddGroup.mk _ AddCommGroup.mkSorryProofs _ TopologicalAddGroup.mkSorryProofs

  abbrev ContinuousSMul.mkSorryProofs {α} [SMul K α] [TopologicalSpace α] :
      ContinuousSMul K α := ContinuousSMul.mk sorry_proof

  abbrev ConvenientSpace.mkSorryProofs {α} [ConvenientAddGroup α] [SMul K α] : ConvenientSpace K α :=
    @ConvenientSpace.mk
      (toModule := Module.mkSorryProofs)
      (toContinuousSMul := ContinuousSMul.mkSorryProofs)
      sorry_proof

  instance [RCLike K] : ConvenientAddGroup K := ⟨⟩
