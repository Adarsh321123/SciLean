-- import SciLean.Core.Functions
-- import SciLean.Tactic

import SciLean.Core.Functions

namespace SciLean

variable {α β γ : Type}
variable {X Y Z : Type} [Hilbert X] [Hilbert Y] [Hilbert Z]
variable {ι κ : Type} [Enumtype ι] [Enumtype κ]

variable {n : Nat} [Nonempty (Fin n)]

example (y : X)
  : 
    ∇ (λ x : X => ⟪x,x⟫) = λ x : X => (1:ℝ) * x + (1:ℝ) * x
  := by simp; unfold hold; simp done

-- @[simp low]
-- This can loop together with `sum_into_lambda`
theorem sum_of_linear {X Y ι} [Enumtype ι] [Vec X] [Vec Y]
  (f : X → Y) [IsLin f]
  (g : ι → X)
  : (∑ i, f (g i)) = f (∑ i, g i)
  := sorry

@[simp] 
theorem sum_into_lambda {X Y ι} [Enumtype ι] [Vec Y]
  (f : ι → X → Y)
  : (∑ i, λ j => f i j) = (λ j => ∑ i, f i j)
  := sorry

@[simp] theorem one_smul {X} [Vec X] (x : X) : (1:ℝ) * x = x := sorry

instance (f : X → Y) [HasAdjDiff f] (x : X) : IsLin (δ† f x) := sorry

-- set_option trace.Meta.Tactic.simp.discharge true in
-- set_option trace.Meta.Tactic.simp.unify true in
@[simp]
theorem asdf [Nonempty ι]
  (f : Y → Z) [HasAdjDiff f]
  (g : X → ι → Y) [HasAdjDiff g]
  : 
    δ† (λ x i => f (g x i)) = λ x dx' => (δ† g x) λ i => ((δ† f) (g x i) (dx' i))
:= by 
  funext x dx';
  simp; simp only [sum_of_linear]; simp
  done


@[simp high] -- try to avoid using this theorem
theorem hohoho [SemiHilbert Y₂] [SemiHilbert Y₁] [Nonempty ι]
  (f : Y₁ → Y₂ → Z) [IsSmooth f]
  [∀ y₂, HasAdjDiff λ y₁ => f y₁ y₂]
  [∀ y₁, HasAdjDiff λ y₂ => f y₁ y₂]
  (g₁ : X → ι → Y₁) [HasAdjDiff g₁]
  (g₂ : X → ι → Y₂) [HasAdjDiff g₂]
  : δ† (λ x i => f (g₁ x i) (g₂ x i))
    = 
    λ x dx' => 
      (δ† g₁ x) (λ i => (δ† (hold λ y₁ => f y₁ (g₂ x i))) (g₁ x i) (dx' i))
      +
      (δ† g₂ x) (λ i => (δ† (hold λ y₂ => f (g₁ x i) y₂)) (g₂ x i) (dx' i))
:= by admit

  -- (apply diag.arg_x.adjDiff_simp (λ y₁ y₂ => f y₁ y₂ a) g₁ g₂)
  -- done

@[simp high + 1] -- try to avoid using this theorem
theorem hohohoo
  (g₁ : X → ι → ℝ) [HasAdjDiff g₁]
  (g₂ : X → ι → Y) [HasAdjDiff g₂]
  : δ† (λ x i => (g₁ x i) * (g₂ x i))
    = 
    λ x dx' => 
      (δ† g₁ x) (λ i => ⟪dx' i, g₂ x i⟫)
      +
      (δ† g₂ x) (λ i => g₁ x i * dx' i)
:= by admit



set_option trace.Meta.Tactic.simp.rewrite true in
example (g : ι → ℝ) [Nonempty ι]
  : 
    ∇ (λ (f : ι → ℝ) => ∑ i, (f i) * (f i)) g 
    = 
    (λ _ => (1 : ℝ)) 
  := by simp; unfold hold; simp done


example 
  : δ (fun (x : Fin n → ℝ) i => x (i + 1) * x i) 
    = 
    (fun x dx a => dx (a + 1) * x a + x (a + 1) * dx a) := 
by
  simp

-- set_option synthInstance.maxHeartbeats 2000 
-- set_option maxHeartbeats 50000 


-- set_option trace.Meta.Tactic.simp.discharge true in
-- set_option trace.Meta.Tactic.simp.rewrite true in
example : adjDiff (fun (x : Fin n → ℝ) => x i) = (fun x dx' j => kron i j * dx') :=
by
  simp
  done


-- @[simp] 
theorem sum_of_add {X ι} [Enumtype ι] [Vec X]
  (f g : ι → X)
  : (∑ i, f i + g i) = (∑ i, f i) + (∑ i, g i)
  := sorry

theorem sum_into_lambda {X Y ι} [Enumtype ι] [Vec Y]
  (f : ι → X → Y)
  : (∑ i, λ j => f i j) = (λ j => ∑ i, f i j)
  := sorry



-- set_option synthInstance.maxHeartbeats 2000 in
-- set_option maxHeartbeats 50000 in
-- set_option trace.Meta.Tactic.simp.discharge true in
-- set_option trace.Meta.Tactic.simp.rewrite true in
-- set_option trace.Meta.Tactic.simp.unify true in
example 
  : ∇ (λ (f : Fin n → ℝ) => ∑ i, (f (i + 1))*(f i))
    = 
    (λ (f : Fin n → ℝ) => (λ i => ⟪1, f (i - 1)⟫) + (λ i => f (i + 1))) 
  := 
by
  simp; simp only [sum_of_add, sum_into_lambda]; simp done
 
/-

-- set_option synthInstance.maxHeartbeats 2000 in
-- set_option maxHeartbeats 50000 in
example 
  : ∇ (λ (f : ℝ^n) => ∑ i, f[i + 1]*f[i])
    = 
    λ (f : ℝ^n) => PowType.intro λ i => f[i - 1] + f[i + 1]
  := 
by 
  simp[gradient, adjoint_differential]
  simp[AtomicAdjointFun.adj,hold]
  done

-/ 


-- set_option trace.Meta.Tactic.simp.discharge true in
example {X} [Hilbert X] (x : X) 
  : 
    ∇ (λ x : X => ∥x∥²) x = (2 : ℝ) * x 
  := 
by simp done 


set_option synthInstance.maxHeartbeats 1000 in
set_option synthInstance.maxSize 2000 in


example (g : Fin n → ℝ)
  : 
    ∇ (λ (f : Fin n → ℝ) => ∑ i, ⟪(f (i + 1) - f i), (f (i + 1) - f i)⟫) g 
    = 
    (λ i => (2 : ℝ) * (g (i - 1 + 1) - g (i - 1) - (g (i + 1) - g i))) 
  := 
by
  funext i; simp; unfold hold; simp;
  
  rw[!?(i - 1 + 1 = i)]
  done

/-

-- set_option synthInstance.maxHeartbeats 50000 in
-- set_option synthInstance.maxSize 2048 in                           
-- example (c : Fin n → ℝ) (k : ℝ) : IsSmooth fun (x : Fin n → Fin 3 → ℝ) (i : Fin n) => ∥ ∥x i - x (i - 1)∥² - (c i) ∥² := by infer_instance

-- Too slow with `x : (ℝ^(3:ℕ))^n
-- Quite compicated
-- set_option trace.Meta.Tactic.simp.discharge true in
-- set_option synthInstance.maxHeartbeats 50000 in
-- set_option synthInstance.maxSize 2048 in                           
-- example (l : Fin n → ℝ)
--   : ∇ (λ (x : Fin n → Fin 3 → ℝ) => ∑ i, ∥ ∥x i  - x (i-1)∥² - (l i)^2∥²)
--     =
--     (fun (x : Fin n → Fin 3 → ℝ) =>
--       (2:ℝ) * fun j =>
--         (∥x j - x (j - 1)∥² - l j ^ 2) * ((2:ℝ) * (x j - x (j - 1))) -
--         (∥x (j + 1) - x (j + 1 - 1)∥² - l (j + 1) ^ 2) * ((2:ℝ) * (x (j + 1) - x (j + 1 - 1))))
--   := 
-- by
  -- conv => 
  --   lhs
  --   simp[gradient]
  -- conv => 
  --   lhs
  --   simp
  -- done

-- set_option trace.Meta.Tactic.simp.rewrite true in
-- set_option synthInstance.maxSize 256 in
-- example
--   : ∇ (λ x : Fin n → Fin 3 → ℝ => ∑ i j, ∥x i - x j∥²)
--     = 
--     0
--    -- (fun x => (2:ℝ) * ((fun j => (n:ℝ) * x j - fun j => sum fun i => x i j) - fun j => (fun j => sum fun i => x i j) - (n:ℝ) * x j))
--  := by
--    autograd    -- I was unable to typecheck the rhs, so we are just checking if `autograd` terminates on this
--    admit

-- set_option trace.Meta.Tactic.simp true in
-- example
--   : 𝓑 (λ x : Fin n → Fin 3 → ℝ => ∑ i j, ∥x i - x j∥²)
--     = 
--     0
--  := by
--    simp    -- I was unable to typecheck the rhs, so we are just checking if `autograd` terminates on this
--    admit


-- set_option synthInstance.maxHeartbeats 1000
-- example (g : ι → ℝ) 
--   : 
--     ∇ (λ (f : ι → ℝ) => ∑ i, (42 : ℝ) * f i) g 
--     = 
--     (λ _ => (42 : ℝ)) 
--   := by autograd done

-- example (g : ι → ℝ) 
--   : 
--     ∇ (λ (f : ι → ℝ) => ∑ i, (f i)*(f i)) g = (2 : ℝ) * g 
--   := 
-- by autograd; done


-- example : δ (λ x : ℝ^n => ∑ i, x[i]) = λ x dx => ∑ i, dx[i] := by simp done
-- example : δ (λ x : ℝ^n => ∑ i, 2*x[i]) = λ x dx => ∑ i, (2:ℝ)*dx[i] := by simp done
-- example : δ (λ x : ℝ^n => (∑ i, x[i]*x[i])) = λ x dx => (∑ i, dx[i]*x[i]) + (∑ i, x[i]*dx[i]) := by simp done
-- example : ∇ (λ x : ℝ^n => ∑ i, x[i]) = λ x => PowType.intro (λ i => (1:ℝ)) := by autograd done
-- example : ∇ (λ x : ℝ^n => ∑ i, x[i]*x[i]) = λ x : ℝ^n => (2:ℝ)*x := by autograd admit -- not quite there,
-- not sure what to do about this case

  --   example : ∇ (λ x => ∑ i, x[i]*x[i-a]) x = ((lmk λ i => x[i-a]) + (lmk λ i => x[i+a])) := by autograd done
  --   -- example : ∇ (λ x => ∑ i, (x[i+a] - x[i])*(x[i+a] - x[i])) x = 0 := by autograd done -- Needs some more sophisticated simplifications

    -- variable {n : Nat} [NonZero n] (a : Fin n)

    -- example : ∇ (λ (f : Fin n → ℝ) => ∑ i, (f (i+a) - f i)*(f (i+a) - f i)) 
    --           = 
    --           (λ (f : Fin n → ℝ) i => 2 * (f (i - a + a) - f (i - a) - (f (i + a) - f i))) := by autograd done
  --   example (c : ℝ) : ∇ (λ (f : Fin n → ℝ) => ∑ i, c*(f i)*(f i)) = (λ (f : Fin n → ℝ) => (2:ℝ)*c*f) := by autograd done

-/
