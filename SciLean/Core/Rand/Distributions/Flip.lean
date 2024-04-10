import SciLean.Core.Rand.Rand
import SciLean.Core.FloatAsReal

open MeasureTheory ENNReal BigOperators Finset

namespace SciLean.Rand

variable {R} [RealScalar R] [MeasureSpace R]

def flip (x : R) : Rand Bool := {
  spec :=
    let t := (Scalar.toReal R x)     -- todo: clamp to [0,1]
    let f := (Scalar.toReal R (1-x)) -- todo: clamp to [0,1]
    erase (fun φ => t • φ true + f • φ false)
  rand :=
    fun g => do
    let (y,g) := (uniformI R).rand g
    let b := if y ≤ x then true else false
    pure (b, g)
}

instance (θ : R) : LawfulRand (flip θ) where
  is_measure := sorry_proof
  is_prob    := sorry_proof

@[rand_simp,simp]
theorem flip.pdf_wrt_flip (θ θ' : R) :
    (flip θ).pdf R (flip θ').ℙ
    =
    fun b => if b then θ / θ' else (1-θ) / (1-θ') := by sorry_proof

@[rand_simp,simp]
theorem flip.pdf (x : R) (_hx : x ∈ Set.Icc 0 1) :
    (flip x).pdf R .count
    =
    fun b => if b then x else (1-x) := by sorry_proof

theorem flip.measure (θ : R) :
    (flip θ).ℙ = (ENNReal.ofReal (Scalar.toReal R θ)) • Measure.dirac true
                 +
                 (ENNReal.ofReal (Scalar.toReal R (1-θ))) • Measure.dirac false :=
  sorry_proof


variable
  {X} [AddCommGroup X] [Module R X] [Module ℝ X]

@[rand_simp,simp]
theorem flip.integral (θ : R) (f : Bool → X) :
    ∫' x, f x ∂(flip θ).ℙ = θ • f true + (1-θ) • f false := by
  simp [rand_simp,flip.measure]; sorry_proof

theorem flip.E (θ : R) (f : Bool → X) :
    (flip θ).𝔼 f = θ • f true + (1-θ) • f false := by
  simp only [𝔼,flip.integral]

theorem add_as_flip_E {x y : X} (θ : R) (h : θ ∈ Set.Ioo 0 1) :
    x + y = (flip θ).𝔼 (fun b => if b then θ⁻¹ • x else (1-θ)⁻¹ • y) := by
  simp[flip.E]
  have : θ ≠ 0 := by aesop
  have : 1 - θ ≠ 0 := by sorry_proof
  simp (disch:=assumption)
