import SciLean.Modules.Prob.DistribDeriv.Distribution

namespace SciLean.Prob


variable
  {W} [NormedAddCommGroup W] [NormedSpace ℝ W] [FiniteDimensional ℝ W] [MeasurableSpace W]
  {X} [NormedAddCommGroup X] [NormedSpace ℝ X] [FiniteDimensional ℝ X] [MeasurableSpace X]
  {Y} [NormedAddCommGroup Y] [NormedSpace ℝ Y] [FiniteDimensional ℝ Y] [MeasurableSpace Y]
  {Z} [NormedAddCommGroup Z] [NormedSpace ℝ Z] [FiniteDimensional ℝ Z] [MeasurableSpace Z]


noncomputable
def distribDeriv
    (f : X → Distribution Y) (x dx : X) : Distribution Y :=
  fun φ => fderiv ℝ (fun x' => (f x') φ) x dx


/-- Differentiable function in distributional sense. No clue how to define this :)

Can we define this such that these  theorems hold?
  1. distribDeriv_comp
  2. Rand.bind.arg_xf.distribDeriv_rule

-/
opaque DistribDifferentiable (f : X → Distribution Y) : Prop


@[simp]
theorem distribDeriv_const (a : Distribution α) :
    distribDeriv (fun _ : X => a)
    =
    fun w dw => 0 := by unfold distribDeriv; simp; rfl


--
axiom distribDeriv_comp
    {X} [NormedAddCommGroup X] [NormedSpace ℝ X]
    {Y Z} [NormedAddCommGroup Y] [NormedSpace ℝ Y]
    (f : Y → Distribution Z) (g : X → Y) (x dx : X) (φ : Z → ℝ)
    (hf : DistribDifferentiable f) (hg : DifferentiableAt ℝ g x) :
    distribDeriv (fun x : X => (f (g x))) x dx φ
    =
    let y := g x
    let dy := fderiv ℝ g x dx
    distribDeriv f y dy φ



-- TODO: mark as axiom - unfortunatelly it add bunch of extra assumptions
theorem Rand.bind.arg_xf.distribDeriv_rule
    {X Y Z} [NormedAddCommGroup X] [NormedSpace ℝ X]
    (g : X → Distribution Y) (f : X → Y → Distribution Z) (φ : Z → ℝ) (w dw : X)
    (hg : DistribDifferentiable g) (hf : DistribDifferentiable (fun (x,y) => f x y)) :
    distribDeriv (fun w => (g w).bind (f w)) w dw φ
    =
    (distribDeriv g w dw).bind (f w · ) φ
    +
    (g w).bind (fun x => distribDeriv (f · x) w dw) φ := sorry


theorem fderiv_uncurry (f : X → Y → Z) (xy dxy : X×Y) (hf : DifferentiableAt ℝ (fun (x,y) => f x y) xy)  :
    fderiv ℝ (fun xy => f xy.1 xy.2) xy dxy
    =
    fderiv ℝ (fun x' => f x' xy.2) xy.1 dxy.1
    +
    fderiv ℝ (fun y' => f xy.1 y') xy.2 dxy.2 := sorry

theorem fderiv_diag (f : X → X → Y) (hf : Differentiable ℝ (fun (x,y) => f x y)) (x dx : X) :
    fderiv ℝ (fun x => f x x) x dx
    =
    fderiv ℝ (fun x' => f x' x) x dx
    +
    fderiv ℝ (fun y' => f x y') x dx := sorry
