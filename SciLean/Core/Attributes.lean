import Lean

namespace SciLean

-- pre pass
-- used to progapage ∂,†,∂†,𝒯,ℛ from the root of the expression to leafs
register_simp_attr autodiff

-- post pass
-- used to do basic algebraic simplifications, runs from leafs to the root
register_simp_attr autodiff_simp
