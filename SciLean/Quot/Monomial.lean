import SciLean.Quot.FreeMonoid
import SciLean.Quot.QuotQ

inductive DecComparison {X : Type u} [LT X] (x y : X) where
  | cpEq (h : x = y) : DecComparison x y
  | cpLt (h : x < y) : DecComparison x y
  | cpGt (h : x > y) : DecComparison x y

export DecComparison (cpEq cpLt cpGt)

class DecCompar (X : Type u) [LT X] where
  compare (x y : X) : DecComparison x y

instance [LT α] [DecidableEq α] [∀ a b : α, Decidable (a < b)] : DecCompar α :=
{
  compare := λ x y =>
    if h : x = y 
    then cpEq h
    else if h : x < y
    then cpLt h
    else cpGt sorry
}

-- instance [LT ι] [Enumtype ι] : DecCompar ι := sorry

instance : DecCompar ℕ :=
{
  compare := λ x y =>
    if h : x = y 
    then cpEq h
    else if h : x < y
    then cpLt h
    else cpGt sorry
}

abbrev compare {X} [LT X] [DecCompar X] (x y : X) : DecComparison x y := DecCompar.compare x y

partial def Nat.toSubscript (n : ℕ) : String := 
  let rec impl (k : ℕ) : String :=
    if k≠0 then
      match k%10 with
      | 0 => impl (k/10) ++ "₀"
      | 1 => impl (k/10) ++ "₁"
      | 2 => impl (k/10) ++ "₂"
      | 3 => impl (k/10) ++ "₃"
      | 4 => impl (k/10) ++ "₄"
      | 5 => impl (k/10) ++ "₅"
      | 6 => impl (k/10) ++ "₆"
      | 7 => impl (k/10) ++ "₇"
      | 8 => impl (k/10) ++ "₈"
      | 9 => impl (k/10) ++ "₉"
      | _ => ""
    else
      ""
  if n=0 then 
    "₀"
  else
    impl n

partial def Nat.toSupscript (n : ℕ) : String := 
  let rec impl (k : ℕ) : String :=
    if k≠0 then
      match k%10 with
      | 0 => impl (k/10) ++ "⁰"
      | 1 => impl (k/10) ++ "¹"
      | 2 => impl (k/10) ++ "²"
      | 3 => impl (k/10) ++ "³"
      | 4 => impl (k/10) ++ "⁴"
      | 5 => impl (k/10) ++ "⁵"
      | 6 => impl (k/10) ++ "⁶"
      | 7 => impl (k/10) ++ "⁷"
      | 8 => impl (k/10) ++ "⁸"
      | 9 => impl (k/10) ++ "⁹"
      | _ => ""
    else
      ""
  if n=0 then 
    "₀"
  else
    impl n

inductive List.Sorted {X : Type u} [LT X] : List X → Prop where
| empty : Sorted []
| singl (x : X) : Sorted [x]
| head  (x y : X) (ys : List X) (h : (x < y) ∨ (x = y)) (h' : Sorted (y :: ys)) 
        : Sorted (x :: y :: ys)

inductive List.StrictlySorted {X : Type u} [LT X] : List X → Prop where
| empty : StrictlySorted []
| singl (x : X) : StrictlySorted [x]
| head  (x y : X) (ys : List X) (h : x < y) 
        (h' : StrictlySorted (y :: ys)) 
        : StrictlySorted (x :: y :: ys)


--- Sorts list and returns the number of transpositions, bool indicates repeated element
partial def List.bubblesortTransNum {α} [LT α] [DecCompar α] (l : List α) : List α × ℕ × Bool :=
  match l with
  | [] => ([], 0, false)
  | x :: xs => 
    match xs.bubblesortTransNum with
    | ([], n, b) => ([x], n, b)
    | (y :: ys, n, b) => 
      match compare x y with
      | cpEq h => (x :: y :: ys, n, true)
      | cpLt h => (x :: y :: ys, n, b)
      | cpGt h => 
        let (xys, n', b') := (x :: ys).bubblesortTransNum
        (y :: xys, n + n' + 1, b ∨ b')

def List.bubblesort {α} [LT α] [DecCompar α] (l : List α) : List α 
  := l.bubblesortTransNum.1

namespace SciLean

open Quot'

class Rank (α : Type u) where
  rank : α → ℕ

def napply (f : α → α) (n : ℕ) (a : α) : α :=
  match n with
  | 0 => a
  | n+1 => napply f n (f a)

export Rank (rank)


class Monomial (M) (K : Type v) (X : Type u) extends HMul K M M, Mul M where
  intro : K → X → M
  base : M → X
  coef : M → K

namespace Monomial 

  structure Repr (K : Type v) (X : Type u) where
    coef : K
    base : FreeMonoid X

  instance {K X} [ToString K] [ToString X] : ToString (Repr K X) :=
   ⟨λ x => s!"{x.coef}*{x.base}"⟩

  instance {K X} [Mul K] [Mul X] : Mul (Repr K X) := 
    ⟨λ x y => ⟨x.coef * y.coef, x.base * y.base⟩⟩

  instance {K X} [Mul K] : HMul K (Repr K X) (Repr K X) := 
    ⟨λ a x => ⟨a * x.coef, x.base⟩⟩
  instance {K X} [Mul K] : HMul (Repr K X) K (Repr K X) := 
    ⟨λ x a => ⟨x.coef * a, x.base⟩⟩

  -- def Repr.rank {K X} (x : Repr K X) : Nat := x.base.rank

  -- Makes only multiplication on X 
  inductive FreeEq (K X) [Zero K] : Repr K X → Repr K X → Prop where
    | refl (x : Repr K X) : FreeEq K X x x
    | zero_coeff (x y : FreeMonoid X) : FreeEq K X ⟨0, x⟩ ⟨0, y⟩

  inductive SymEq (K X) [Zero K] : Repr K X → Repr K X → Prop where
    | eq (x y : Repr K X) (h : FreeEq K X x y) : SymEq K X x y
    | sym_mul (c : K) (x y : FreeMonoid X) : SymEq K X ⟨c, x * y⟩ ⟨c, y * x⟩

  inductive AltEq (K X) [Zero K] [Neg K] : Repr K X → Repr K X → Prop where
    | eq (x y : Repr K X) (h : FreeEq K X x y) : AltEq K X x y
    | alt_mul (c : K) (x y : FreeMonoid X) : AltEq K X ⟨c, x * y⟩ ⟨napply Neg.neg (x.rank * y.rank) c, y * x⟩

  instance {K X} [Zero K] : QForm (FreeEq K X) :=
  {
    RedForm := λ _ => True
    NormForm := λ x => (x.coef = 0 → x.base = 1)
    norm_red := λ x _ => True.intro
    norm_eq := sorry
  }

  instance {K X} [LT X] [Zero K] : QForm (SymEq K X) :=
  {
    RedForm := λ x => x.base.1.Sorted
    NormForm := λ x => x.base.1.Sorted ∧ (x.coef = 0 → x.base = 1)
    norm_red := λ x h => h.1
    norm_eq := sorry
  }

  instance {K X} [LT X] [Zero K] [Neg K] : QForm (AltEq K X) :=
  {
    RedForm := λ x => x.base.1.StrictlySorted
    NormForm := λ x => x.base.1.StrictlySorted ∧ (x.coef = 0 → x.base = 1)
    norm_red := λ x h => h.1
    norm_eq := sorry
  }

  instance {K X} [Zero K] [Reduce K] : QReduce (FreeEq K X) :=
  {
    reduce := λ x => ⟨reduce x.coef, x.base⟩
    is_reduce := sorry
    eq_reduce := sorry
    preserve_norm := sorry
  }

  instance {K X} [LT X] [DecCompar X] [Zero K] [Reduce K] : QReduce (SymEq K X) :=
  {
    reduce := λ x => ⟨reduce x.coef, ⟨x.base.1.bubblesort⟩⟩
    is_reduce := sorry
    eq_reduce := sorry
    preserve_norm := sorry
  }

  -- TODO: Check for repeated element in monomial
  instance {K X} [LT X] [DecCompar X] [Zero K] [Neg K] [Reduce K] : QReduce (AltEq K X) :=
  {
    reduce := λ x =>
      let (xb, n, b) := x.base.1.bubblesortTransNum
      if b then
        ⟨0, 1⟩
      else
        let c := reduce <| if n%2==0 then x.coef else -x.coef
        ⟨c, ⟨xb⟩⟩
    is_reduce := sorry
    eq_reduce := sorry
    preserve_norm := sorry
  }

  instance {K X} [DecidableEq K] [Zero K] [Normalize K] : QNormalize (FreeEq K X) :=
  {
    normalize := λ x => 
      let c := normalize x.coef
      if c = 0 then ⟨0, 1⟩ else ⟨c, x.base⟩
    is_normalize := sorry
    eq_normalize := sorry
  }

  instance {K X} [LT X] [DecCompar X] [DecidableEq K] [Zero K] [Normalize K] : QNormalize (SymEq K X) :=
  {
    normalize := λ x => 
      let c := normalize x.coef
      let b := x.base.1.bubblesort
      if c = 0 then ⟨0, 1⟩ else ⟨c, ⟨b⟩⟩
    is_normalize := sorry
    eq_normalize := sorry
  }

  -- TODO: Check for repeated element in monomial
  instance {K X} [LT X] [DecCompar X] [DecidableEq K] [Zero K] [Neg K] [Normalize K] : QNormalize (AltEq K X) :=
  {
    normalize := λ x => 
      let (xb, n, b) := x.base.1.bubblesortTransNum
      if b then 
        ⟨0, 1⟩
      else
        let c := normalize x.coef
        let c := if (n%2 == 0) then c else -c
        if c = 0 then ⟨0, 1⟩ else ⟨c, ⟨xb⟩⟩
    is_normalize := sorry
    eq_normalize := sorry
  }

end Monomial 
  
def FreeMonomial (K : Type v) (X : Type u) [Zero K] := 
  Quot' (Monomial.FreeEq K X)

def SymMonomial (K : Type v) (X : Type u) [LT X] [Zero K] := 
  Quot' (Monomial.SymEq K X)

def AltMonomial (K : Type v) (X : Type u) [LT X] [Neg K] [Zero K]:= 
  Quot' (Monomial.AltEq K X)

namespace FreeMonomial
  open Monomial

  variable {K X} [Zero K] [Mul K] [DecidableEq K] [Reduce K] [Normalize K]  --[QNormalize (FreeEq K X)]

  instance (c : K) : IsQHom (FreeEq K X) (FreeEq K X) (λ x => ⟨c*x.coef, x.base⟩) := sorry
  instance (c : K) : IsQHomR (FreeEq K X) (FreeEq K X) (λ x => ⟨c*x.coef, x.base⟩) := sorry
  instance : HMul K (FreeMonomial K X) (FreeMonomial K X) :=
  ⟨
    λ c m => Quot'.rlift (λ x => ⟨c*x.coef, x.base⟩) m
  ⟩

  instance : IsQHom₂ (FreeEq K X) (FreeEq K X) (FreeEq K X) 
    (λ x y => ⟨x.coef*y.coef, x.base*y.base⟩) := sorry
  instance : Mul (FreeMonomial K X) :=
  ⟨Quot'.lift₂ (λ x y => ⟨x.coef*y.coef, x.base*y.base⟩)⟩

  instance : Monomial (FreeMonomial K X) K (FreeMonoid X) :=
  {
    intro := λ k x => ⟦QRepr.raw ⟨k, x⟩⟧
    base := λ m => m.nrepr.base
    coef := λ m => m.nrepr.coef
  }

  def toString [ToString X] [ToString K] 
    (mul smul : String) (m : FreeMonomial K X) : String
    := 
  Id.run do
    let m' := m.nrepr
    let mut s := s!"{m'.coef}{smul}{m'.base.toString mul}"
    s

  instance [ToString X] [ToString K] : ToString (FreeMonomial K X) 
    := ⟨λ m => m.toString "⊗" "*"⟩

  instance [QReduce (FreeEq K X)] : Reduce (FreeMonomial K X) := Quot'.instReduceQuot'
  instance [QNormalize (FreeEq K X)] : Normalize (FreeMonomial K X) := Quot'.instNormalizeQuot'

end FreeMonomial

namespace SymMonomial
  open Monomial

  variable {K X} [LT X] [DecCompar X] [DecidableEq K] [Zero K] [Mul K] [Reduce K] [Normalize K] -- [QNormalize (SymEq K X)]

  instance (c : K) : IsQHom (SymEq K X) (SymEq K X) (λ x => ⟨c*x.coef, x.base⟩) := sorry
  instance (c : K) : IsQHomR (SymEq K X) (SymEq K X) (λ x => ⟨c*x.coef, x.base⟩) := sorry
  instance : HMul K (SymMonomial K X) (SymMonomial K X) :=
  ⟨
    λ c m => Quot'.rlift (λ x => ⟨c*x.coef, x.base⟩) m
  ⟩

  instance : IsQHom₂ (SymEq K X) (SymEq K X) (SymEq K X) 
    (λ x y => ⟨x.coef*y.coef, x.base*y.base⟩) := sorry
  instance : Mul (SymMonomial K X) :=
  ⟨Quot'.lift₂ (λ x y => ⟨x.coef*y.coef, x.base*y.base⟩)⟩

  instance : Monomial (SymMonomial K X) K (FreeMonoid X) :=
  {
    intro := λ k x => ⟦QRepr.raw ⟨k, x⟩⟧
    base := λ m => m.nrepr.base
    coef := λ m => m.nrepr.coef
  }

  def toString [ToString X] [ToString K] 
    (mul smul : String) (m : SymMonomial K X) : String
    := 
  Id.run do
    let m' := m.nrepr
    let mut s := s!"{m'.coef}{smul}{m'.base.toString mul}"
    s

  instance [ToString X] [ToString K] : ToString (SymMonomial K X) 
    := ⟨λ m => m.toString "*" "*"⟩

  instance [QReduce (SymEq K X)] : Reduce (SymMonomial K X) := Quot'.instReduceQuot'
  instance [QNormalize (SymEq K X)] : Normalize (SymMonomial K X) := Quot'.instNormalizeQuot'

end SymMonomial

namespace AltMonomial
  open Monomial

  variable {K X} [LT X] [DecCompar X] [Zero K] [Neg K] [Mul K] [Normalize K] [DecidableEq K] -- [QNormalize (AltEq K X)] 

  instance (c : K) : IsQHom (AltEq K X) (AltEq K X) (λ x => ⟨c*x.coef, x.base⟩) := sorry
  instance (c : K) : IsQHomR (AltEq K X) (AltEq K X) (λ x => ⟨c*x.coef, x.base⟩) := sorry
  instance : HMul K (AltMonomial K X) (AltMonomial K X) :=
  ⟨
    λ c m => Quot'.rlift (λ x => ⟨c*x.coef, x.base⟩) m
  ⟩

  instance : IsQHom₂ (AltEq K X) (AltEq K X) (AltEq K X) 
    (λ x y => ⟨x.coef*y.coef, x.base*y.base⟩) := sorry
  instance : Mul (AltMonomial K X) :=
  ⟨Quot'.lift₂ (λ x y => ⟨x.coef*y.coef, x.base*y.base⟩)⟩

  instance : Monomial (AltMonomial K X) K (FreeMonoid X) :=
  {
    intro := λ k x =>  ⟦QRepr.raw ⟨k, x⟩⟧
    base := λ m => m.nrepr.base
    coef := λ m => m.nrepr.coef
  }

  def toString [ToString X] [ToString K] 
    (mul smul : String) (m : AltMonomial K X) : String
    := 
  Id.run do
    let m' := m.nrepr
    let mut s := s!"{m'.coef}{smul}{m'.base.toString mul}"
    s

  instance [ToString X] [ToString K] : ToString (AltMonomial K X) 
    := ⟨λ m => m.toString "∧" "*"⟩

  instance [ToString K] : ToString (AltMonomial K Nat) 
    := ⟨λ m => m.toString "∧" "*"⟩


  instance [QReduce (AltEq K X)] : Reduce (AltMonomial K X) := Quot'.instReduceQuot'
  instance [QNormalize (AltEq K X)] : Normalize (AltMonomial K X) := Quot'.instNormalizeQuot'

end AltMonomial

#eval ( (10 : ℕ).toSubscript)

def m : FreeMonomial Int Nat := ⟦QRepr.raw ⟨1, ⟨[0,2,0,3]⟩⟩⟧
def p : SymMonomial Int Nat := ⟦QRepr.raw ⟨1, ⟨[0,2,0,3]⟩⟩⟧
def w : AltMonomial Int Nat := ⟦QRepr.raw ⟨2, ⟨[1,0,3]⟩⟩⟧
def w' : AltMonomial Int Nat := ⟦QRepr.raw ⟨0, ⟨[5,2]⟩⟩⟧
def w'' : AltMonomial Int Nat := ⟦QRepr.raw ⟨3, ⟨[5,2]⟩⟩⟧

#check Quot'.instNormalizeQuot'.normalize

#eval m
#eval p
#eval w.toDebugString
#eval w*w''
#eval w |> Quot'.instNormalizeQuot'.normalize |>.toDebugString
#eval w |> normalize |>.toDebugString
#eval w'.toDebugString
#eval (w' |> reduce).toDebugString
#eval (w' |> normalize).toDebugString


#eval (w*w').toDebugString
#eval (w*w' |> reduce).toDebugString
#eval (w*w' |> normalize).toDebugString




-- 𝔁[0] 𝓭𝔁[] 𝓮[0] 


