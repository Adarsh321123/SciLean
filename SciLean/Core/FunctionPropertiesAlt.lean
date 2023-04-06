import SciLean.Core.Attributes
import SciLean.Core.Defs
import SciLean.Core.Meta.FunctionProperty
import SciLean.Core.Meta.RewriteBy

import SciLean.Tactic.AutoDiff

import SciLean.Data.ArraySet

import SciLean.Core.FunctionTheorems


namespace SciLean

set_option linter.unusedVariables false 

open Lean Parser.Term Lean.Elab Meta

#check mkApp

def uncurryN' {F : Type} {Xs Y : outParam Type} 
  (n : Nat) (f : F) [Prod.Uncurry n F Xs Y] 
  := uncurryN n f


def _root_.Lean.Meta.getConstExplicitArgIdx (constName : Name) : MetaM (Array Nat) := do
  let info ← getConstInfo constName

  let (_, explicitArgIdx) ← forallTelescope info.type λ Xs _ => do
    Xs.foldlM (init := (0,(#[] : Array Nat))) 
      λ (i, ids) X => do 
        if (← X.fvarId!.getBinderInfo).isExplicit then
          pure (i+1, ids.push i)
        else
          pure (i+1, ids)

  return explicitArgIdx

def _root_.Lean.Meta.getConstArity (constName : Name) : MetaM Nat := do
  let info ← getConstInfo constName
  return info.type.forallArity

/--
  Same as `mkAppM` but does not leave trailing implicit arguments.

  For example for `foo : (X : Type) → [OfNat 0 X] → X` the ``mkAppNoTrailingM `foo #[X]`` produces `foo X : X` instead of `@foo X : [OfNat 0 X] → X`
-/
def _root_.Lean.Meta.mkAppNoTrailingM (constName : Name) (xs : Array Expr) : MetaM Expr := do

  let n ← getConstArity constName
  let explicitArgIds ← getConstExplicitArgIdx constName

  -- number of arguments to apply
  let argCount := explicitArgIds[xs.size]? |>.getD n

  let mut args : Array (Option Expr) := Array.mkArray argCount none
  for i in [0:xs.size] do
    args := args.set! explicitArgIds[i]! (.some xs[i]!)

  mkAppOptM constName args


@[inline]
def _root_.Array.partitionIdxM {m} [Monad m] (p : α → m Bool) (as : Array α) : m (Array α × Array α × Array (Sum Nat Nat)) := do
  let mut bs := #[]
  let mut cs := #[]
  let mut ids : Array (Sum Nat Nat) := #[]
  let mut i := 0
  let mut j := 0
  for a in as do
    if ← p a then
      bs := bs.push a
      ids := ids.push (.inl i)
      i := i + 1
    else
      cs := cs.push a
      ids := ids.push (.inr j)
      j := j + 1
  return (bs, cs, ids)

def _root_.Array.merge (ids : Array (Sum Nat Nat)) (bs cs : Array α) [Inhabited α] : Array α :=
  ids.map λ id => 
    match id with
    | .inl i => bs[i]!
    | .inr j => cs[j]!

variable [MonadControlT MetaM n] [Monad n]

#check map2MetaM

@[inline] def _root_.Lean.Meta.map3MetaM [MonadControlT MetaM m] [Monad m] (f : forall {α}, (β → γ → δ → MetaM α) → MetaM α) {α} (k : β → γ → δ → m α) : m α :=
  controlAt MetaM fun runInBase => f (fun b c d => runInBase <| k b c d)

@[inline] def _root_.Lean.Meta.map4MetaM [MonadControlT MetaM m] [Monad m] (f : forall {α}, (β → γ → δ → ε → MetaM α) → MetaM α) {α} (k : β → γ → δ → ε → m α) : m α :=
  controlAt MetaM fun runInBase => f (fun b c d e => runInBase <| k b c d e)

private def createCompositionImpl (e : Expr) (xs : Array Expr) (k : (T : Expr) → (t : Expr) → (ys : Array Expr) → (e' : Expr) → MetaM α) : MetaM α := do
  withLocalDecl `T .implicit (mkSort levelOne) λ T => do
    withLocalDecl `t .default T λ t => do
      
      let xIds := xs.map λ x => x.fvarId!

      -- We are not using `withLocalDecls` as it requires `Inhabited α` and that 
      -- does not play well with map4MetaM
      let mut lctx ← getLCtx
      let mut i := lctx.numIndices
      let mut ys : Array Expr := .mkEmpty xs.size
      for id in xIds do 
        let name ← id.getUserName
        let bi ← id.getBinderInfo 
        let type ← mkArrow T (← id.getType)
        let yId ← mkFreshFVarId
        ys := ys.push (mkFVar yId)
        lctx := lctx.addDecl (mkLocalDeclEx i yId name type bi)
        i := i + 1

      withLCtx lctx (← getLocalInstances) do
        let yts ← ys.mapM λ y => mkAppM' y #[t]
        let replacePairs := xIds.zip yts
        let e' := replacePairs.foldl (init:=e) λ e (id,yt) => e.replaceFVarId id yt

        k T t ys e'

/-- 
  For every free variable `x : X` introduce `y : T → X` and replace every `x` in `e` with `y t`.

  Then call `k` on `e` providing the newly introduces `T`, `t`, `ys`
  -/
def createComposition  (e : Expr) (xs : Array Expr) (k : (T : Expr) → (t : Expr) → (ys : Array Expr) → (e' : Expr) → n α) : n α := 
  map4MetaM (fun k => createCompositionImpl e xs k) k


-- def createCompositionOtherImpl (e : Expr) (xs : Array Expr) (other : Array Expr) 
--   (k : (T : Expr) → (t : Expr) →  (ys : Array Expr) → (other' : Array Expr) → (e' : Expr) → MetaM α) : MetaM α := do

/-- 
  For every free variable `x : X`, elements of `xs`, introduce `y : T → X`, elements of `ys`, and: 
    - replace every `x` in `e` with `y t` 
    - replace every `x` in `other` with `y`.
  where `{T : Type} (t : T)` are newly introduced free variables

  Then call `k` on `e` providing `T`, `t`, `ys` `other`

  NOTE: Most likely this operation makes sense only if `other` is a list of free variables
  -/
def createCompositionOther (e : Expr) (xs : Array Expr) (other : Array Expr) 
  (k : (T : Expr) → (t : Expr) →  (ys : Array Expr) → (other' : Array Expr) → (e' : Expr) → n α) : n α := do

  createComposition e xs λ T t ys e => do 
    
    let other := other.map λ e' => 
      e'.replace (λ e'' => Id.run do
        for (x, y) in xs.zip ys do
          if e'' == x then 
            return some y
        return none)

    k T t ys other e

/-- 
Applies `funName` to `e` but as a composition through arguments specified by `argIds`

This means, for `e = f x₁ .. xₙ` return expression `λ {T} [Space T] a₁ ... aₘ [FunProp xᵢ] : Fun λ t => f x₁ .. (xᵢ t) xₙ` 

where:
  - `Fun`, `FunProp`, `Space` correspond to `funName`, `propName`, `spaceName`
  - `i ∈ argIds`
  - `a₁, ..., aₘ ∈ abstractOver` but any occurance of `xᵢ : X` is replaced with `xᵢ : T → X` 
For example:
```
createFunProp ``differential ``IsSmooth ``Vec (@HAdd.hAdd X X X inst.toHAdd x y) #[4] #[X, inst, x, y]
```
produces
```
∀ {T : Type} [Vec T] {X} [inst : Vec X] (x : X) (y : T → X) [IsSmooth y] : differential λ t => x + (y t)
```
-/
def mkCompositionFunApp (funName propName spaceName : Name) (e : Expr) (argIds : ArraySet Nat) (abstractOver : Array Expr) : MetaM Expr := do

  let args := e.getAppArgs

  let xs := argIds.data.map λ i => args[i]!

  createCompositionOther e xs abstractOver λ T t ys abstractOver e => do

    withLocalDecl `inst .instImplicit (← mkAppM spaceName #[T]) λ SpaceT => do

      let funPropDecls ← ys.mapM λ y => do
        let name := `inst
        let bi := BinderInfo.instImplicit
        let type ← mkAppM propName #[y]
        pure (name, bi, λ _ => pure type)
  
      withLocalDecls funPropDecls λ ysProp => do
        let vars := #[T,SpaceT]
          |>.append abstractOver
          |>.append ysProp
        let statement ← mkAppM funName #[← mkLambdaFVars #[t] e]
        mkForallFVars vars statement

/-- Makes a type that says that `f x₁ .. xₙ` satisfies function propsotion `propName` in `xᵢ`
  
  The returned expression is: `∀ a₁ ... aₘ : FunProp λ xᵢ => f x₁ .. xᵢ xₙ` 
  where `a₁, ..., aₘ ∈ abstractOver` -/
def mkSingleArgFunApp (funName : Name) (e : Expr) (i : Nat) (abstractOver : Array Expr) : MetaM Expr := do

  let args := e.getAppArgs

  let xi := args[i]!

  let statement ← mkAppM funName #[← mkLambdaFVars #[xi] e]

  let abstractOver := abstractOver.filter (λ a => a != xi)

  mkForallFVars abstractOver statement


/--
  Creates argument suffix for a constant and specified arguments.

  Examples:

    For `constName = ``foo` where `foo : ∀ (α : Type) → [inst : Add α] → (x y : α) → α`
    and `argIds = #[2,3]`
    returns `xy` because the third argument has name `x` and the fourth argument has name `y`

    For `HAdd.hAdd : ∀ (α β γ : Type) → [inst : HAdd α β γ] → α → β → γ`
    and `argIds = #[4,5]`
    returns `a4a5` beause fifth and sixth arguments are anonymous
  -/
def constArgSuffix (constName : Name) (argIds : ArraySet Nat) : MetaM String := do

  let info ← getConstInfo constName
  let suffix ← forallTelescope info.type λ args _ => do
    IO.println s!"{← (args.mapM λ arg => ppExpr arg)}"
    (argIds.data.mapM λ i => do
      let name ← args[i]!.fvarId!.getUserName
      IO.println s!"{← ppExpr args[i]!}"
      if name.isInternal then
        return name.eraseMacroScopes.appendAfter (toString i)
      else
        return name)

  return suffix.foldl (init:="") λ s n => s ++ toString n             

/--
For `#[x₁, .., xₙ]` create `(x₁, .., xₙ)`.
-/
def mkProdElem (xs : Array Expr) : MetaM Expr := do
  if xs.size = 0 then
    return default
  if xs.size = 1 then
    return xs[0]!
  else
    xs[:xs.size-1].foldrM (init:=xs[xs.size-1]!) 
      λ x p => 
        mkAppM ``Prod.mk #[x,p]

/--
For `(x₀, .., xₙ₋₁)` return `xᵢ` but as a product projection.

For example for `xyz : X × Y × Z`, `mkProdProj xyz 1` returns `xyz.snd.fst`.
-/
def mkProdProj (x : Expr) (i : Nat) : MetaM Expr := do
  let X ← inferType x
  if X.isAppOfArity ``Prod 2 then
     match i with
     | 0 => mkAppM ``Prod.fst #[x]
     | n+1 => mkProdProj (← mkAppM ``Prod.snd #[x]) n
  else
    if i = 0 then
      return x
    else
      throwError "Failed `mkProdProd`, can't take {i}-th element of {← ppExpr x}. It is not a product type!"

/--
For free variables `#[x₁, .., xₙ]` create a fitting name for a variable of type `X₁ × .. × Xₙ`

Returns `x₁..xₙ`, for example for `#[x,y]` returns `xy`
 -/
def mkProdFVarName (xs : Array Expr) : MetaM Name := do
  xs.foldlM (init:="") λ n x => do return (n ++ toString (← x.fvarId!.getUserName))


/--
For expression `e` and free variables `xs = #[x₁, .., xₙ]`
Return 
```
FunProp (uncurryN n λ x₁ .. xₙ => e)
```
 -/
def mkTargetExprFunProp (funProp : Name) (e : Expr) (xs : Array Expr) : MetaM Expr := do

  let n := xs.size
  let nExpr := mkNatLit n

  -- P = FunProp (uncurryN n λ x₁' .. xₙ' => e)
  let P ← 
    mkAppNoTrailingM ``uncurryN #[nExpr, ← mkLambdaFVars xs e]
    >>=
    λ e' => mkAppM funProp #[e']

  return P


def mkNormalTheoremFunProp (funProp : Name) (e : Expr) (xs : Array Expr) (contextVars : Array Expr) : MetaM Expr := do
  let statement ← mkTargetExprFunProp funProp e xs 

  -- filter out xs from contextVars

  let contextVars := contextVars.filter 
    λ var => 
      if xs.find? (λ x => var == x) |>.isSome then
        false
      else 
        true

  mkForallFVars contextVars statement

def mkCompTheoremFunProp (funProp spaceName : Name) (e : Expr) (xs : Array Expr) (contextVars : Array Expr) : MetaM Expr := do

  createCompositionOther e xs contextVars λ T t ys abstractOver e => do

    withLocalDecl `inst .instImplicit (← mkAppM spaceName #[T]) λ SpaceT => do

      let funPropDecls ← ys.mapM λ y => do
        let name := `inst
        let bi := BinderInfo.instImplicit
        let type ← mkAppM funProp #[y]
        pure (name, bi, λ _ => pure type)
  
      withLocalDecls funPropDecls λ ysProp => do
        let vars := #[T,SpaceT]
          |>.append abstractOver
          |>.append ysProp
        let statement ← mkAppM funProp #[← mkLambdaFVars #[t] e]
        mkForallFVars vars statement


/--
For expression `e = f y₁ .. yₘ` and free variables `xs = #[x₁, .., xₙ]`
Return 
```
λ dx₁ .. dxₙ => ∂ (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ']) (x₁, .., xₙ) (dx₁, .., dxₙ)
```
 -/
def mkTargetExprDifferential (e : Expr) (xs : Array Expr) : MetaM Expr := do

  let n := xs.size
  let nExpr := mkNatLit n

  -- f' = ∂ (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])
  let f' ← 
    mkAppNoTrailingM ``uncurryN #[nExpr, ← mkLambdaFVars xs e]
    >>=
    λ e' => mkAppM ``differential #[e']

  let dxDecls ← xs.mapM λ x => do
    let id := x.fvarId!
    let name := (← id.getUserName).appendBefore "d"
    let bi ← id.getBinderInfo
    let type ← id.getType
    pure (name, bi, λ _ => pure type)

  withLocalDecls dxDecls λ dxs => do
    
    let xsProd  ← mkProdElem xs
    let dxsProd ← mkProdElem dxs

    mkLambdaFVars dxs (← mkAppM' f' #[xsProd, dxsProd])

/--
For expression `e = f y₁ .. yₘ` and free variables `xs = #[x₁, .., xₙ]`
Return 
```
λ dx₁ .. dxₙ => 𝒯 (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ']) (x₁, .., xₙ) (dx₁, .., dxₙ)
```
 -/
def mkTargetExprTangentMap (e : Expr) (xs : Array Expr) : MetaM Expr := do

  let n := xs.size
  let nExpr := mkNatLit n

  -- f' = 𝒯 (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])
  let f' ← 
    mkAppNoTrailingM ``uncurryN #[nExpr, ← mkLambdaFVars xs e]
    >>=
    λ e' => mkAppM ``tangentMap #[e']

  let dxDecls ← xs.mapM λ x => do
    let id := x.fvarId!
    let name := (← id.getUserName).appendBefore "d"
    let bi ← id.getBinderInfo
    let type ← id.getType
    pure (name, bi, λ _ => pure type)

  withLocalDecls dxDecls λ dxs => do
    
    let xsProd  ← mkProdElem xs
    let dxsProd ← mkProdElem dxs

    mkLambdaFVars dxs (← mkAppM' f' #[xsProd, dxsProd])


/--
For expression `e = f y₁ .. yₘ` and free variables `xs = #[x₁, .., xₙ]`
Return 
```
λ (xs' : X₁ × .. Xₙ) => (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])† xs'
```
where `xᵢ : Xᵢ`
 -/
def mkTargetExprAdjoint (e : Expr) (xs : Array Expr) : MetaM Expr := do
  
  let n := xs.size
  let nExpr := mkNatLit n

  -- f' = (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])†
  let f' ← 
    mkAppNoTrailingM ``uncurryN #[nExpr, ← mkLambdaFVars xs e]
    >>=
    λ e' => mkAppM ``adjoint #[e']
  
  let xsProdName ← mkProdFVarName xs
  let bi : BinderInfo := default
  let xsProdType ← inferType (← mkProdElem xs)

  withLocalDecl xsProdName bi xsProdType λ xsProd => do

    mkLambdaFVars #[xsProd] (← mkAppM' f' #[xsProd])


/--
For expression `e = f y₁ .. yₘ` and free variables `xs = #[x₁, .., xₙ]`
Return 
```
λ (dxs' : X₁ × .. Xₙ) => ∂† (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])† (x₁, .., xₙ) dxs'
```
where `xᵢ : Xᵢ`
 -/
def mkTargetExprAdjDiff (e : Expr) (xs : Array Expr) : MetaM Expr := do
  
  let n := xs.size
  let nExpr := mkNatLit n

  -- f' = ∂† (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])
  let f' ← 
    mkAppNoTrailingM ``uncurryN #[nExpr, ← mkLambdaFVars xs e]
    >>=
    λ e' => mkAppM ``adjoint #[e']
  
  let dxsName := (← mkProdFVarName xs).appendBefore "d"
  let bi : BinderInfo := default
  let dxsType ← inferType (← mkProdElem xs)

  withLocalDecl dxsName bi dxsType λ dxs => do

    let xsProd  ← mkProdElem xs

    mkLambdaFVars #[dxs] (← mkAppM' f' #[xsProd, dxs])


/--
For expression `e = f y₁ .. yₘ` and free variables `xs = #[x₁, .., xₙ]`
Return 
```
ℛ (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])† (x₁, .., xₙ)'
```
 -/
def mkTargetExprRevDiff (e : Expr) (xs : Array Expr) : MetaM Expr := do
  
  let n := xs.size
  let nExpr := mkNatLit n

  -- f' = ℛ (uncurryN n λ x₁' .. xₙ' => f y₁[xᵢ:=xᵢ'] .. yₘ[xᵢ:=xᵢ'])
  let f' ← 
    mkAppNoTrailingM ``uncurryN #[nExpr, ← mkLambdaFVars xs e]
    >>=
    λ e' => mkAppM ``adjoint #[e']
  
  return f'

/--
Applies function transformation to `λ x₁ .. xₙ => e` w.r.t. to all the free variables `xs = #[x₁, .., xₙ]`
-/
def mkTargetExpr (transName : Name) (e : Expr) (xs : Array Expr) : MetaM Expr := do
  if transName == ``differential then
    mkTargetExprDifferential e xs
  else if transName == ``tangentMap then
    mkTargetExprTangentMap e xs
  else if transName == ``adjoint then
    mkTargetExprAdjoint e xs
  else if transName == ``adjointDifferential then
    mkTargetExprAdjDiff e xs
  else if transName == ``reverseDifferential then
    mkTargetExprRevDiff e xs
  else
    throwError "Error in `mkTargetExpr`, unrecognized function transformation `{transName}`."


/--
`targetproof` is a proof that `targetExpr` is propositionally equal to `mkTargetExprDifferential e xs`

Assuming that `xs` is a subset of `contextVars`
-/
def mkCompTheoremDifferential (e : Expr) (xs : Array Expr) (targetExpr : Expr) (targetProof : Expr) (contextVars : Array Expr) : MetaM (Expr × Expr) := do

  createCompositionOther e xs contextVars λ T t ys contextVars e => do

    withLocalDecl `inst .instImplicit (← mkAppM ``Vec #[T]) λ SpaceT => do
      let dtName := (← t.fvarId!.getUserName).appendBefore "d"
      withLocalDecl dtName .default (← inferType t) λ dt => do

        let funPropDecls ← ys.mapM λ y => do
          let name := `inst
          let bi := BinderInfo.instImplicit
          let type ← mkAppM ``IsSmooth #[y]
          pure (name, bi, λ _ => pure type)

        withLocalDecls funPropDecls λ ysProp => do
          let contextVars := #[T,SpaceT]
            |>.append contextVars
            |>.append ysProp

          let lhs ← mkAppM ``differential #[← mkLambdaFVars #[t] e]

          let mut lctx ← getLCtx
          let mut i := lctx.numIndices
          let mut xs'  : Array Expr := .mkEmpty xs.size
          let mut dxs' : Array Expr := .mkEmpty xs.size
          for y in ys do 
            let id := y.fvarId!
            let  xName := (← id.getUserName).appendAfter "'"
            let dxName := xName.appendBefore "d"
            let  xVal ← mkAppM' y #[t]
            let dxVal ← mkAppM' (← mkAppM ``differential #[y]) #[t,dt]
            let  xType ← inferType xVal
            let dxType ← inferType dxVal
            let  xId ← mkFreshFVarId
            let dxId ← mkFreshFVarId
            xs'  :=  xs'.push (mkFVar  xId)
            dxs' := dxs'.push (mkFVar dxId)
            lctx := lctx.addDecl (mkLetDeclEx i xId xName xType xVal)
            lctx := lctx.addDecl (mkLetDeclEx (i+1) dxId dxName dxType dxVal)
            i := i + 2

          withLCtx lctx (← getLocalInstances) do

            let rhs ← 
              mkLambdaFVars xs targetExpr -- abstract old xs
              >>=
              λ e => mkAppM' e xs' >>= pure ∘ Expr.headBeta  -- replace xs with xs' 
              >>=
              λ e => mkAppM' e dxs' >>= pure ∘ Expr.headBeta -- apply dxs'
              >>=
              λ e => mkLambdaFVars (xs'.append dxs') e
              >>=
              λ e => mkLambdaFVars #[t,dt] e  -- abstract over t and dt

            pure (← mkForallFVars contextVars (← mkEq lhs rhs), default)


def mkCompTheorem (transName : Name) (e : Expr) (xs : Array Expr) (targetExpr : Expr) (targetProof : Expr) (contextVars : Array Expr) : MetaM (Expr × Expr) := do
  if transName == ``differential then
    mkCompTheoremDifferential e xs targetExpr targetProof contextVars    
  else
    throwError "Error in `mkCompTheorem`, unrecognized function transformation `{transName}`."


def _root_.Lean.TSyntax.argSpecNames (argSpec : TSyntax ``argSpec) : Array Name := 
  match argSpec with 
  | `(argSpec| $id:ident) => #[id.getId]
  | `(argSpec| ($id:ident, $ids:ident,*)) => #[id.getId].append (ids.getElems.map λ id => id.getId)
  | _ => #[]

syntax "funProp" ident ident bracketedBinder* ":=" term : argProp
syntax "funTrans" ident bracketedBinder* ":=" term "by" term: argProp

elab_rules : command
| `(function_property $id $parms* $[: $retType:term]? 
    argument $argSpec $assumptions1*
    funProp $propId $spaceId $assumptions2* := $proof) => do

  Command.liftTermElabM  do

    Term.elabBinders (parms |>.append assumptions1 |>.append assumptions2) λ contextVars => do

      let propName := propId.getId
      let spaceName := spaceId.getId
  
      let argNames : Array Name := argSpec.argSpecNames 

      let explicitArgs := (← contextVars.filterM λ x => do pure (← x.fvarId!.getBinderInfo).isExplicit)
      let e ← mkAppM id.getId explicitArgs
      let args := e.getAppArgs

      let mainArgIds ← argNames.mapM λ name => do
        let idx? ← args.findIdxM? (λ arg => do
          if let .some fvar := arg.fvarId? then
            let name' ← fvar.getUserName
            pure (name' == name)
          else 
            pure false)
        match idx? with
        | some idx => pure idx
        | none => throwError "Specified argument `{name}` is not valid!"

      let xs := mainArgIds.map λ i => args[i]!
      let mainArgIds := mainArgIds.toArraySet


      -- normal theorem - in the form `FunProp (uncurryN n λ x₁ .. xₙ => e)`
      let normalTheorem ← mkNormalTheoremFunProp propName e xs contextVars >>= instantiateMVars

      let prf ← forallTelescope normalTheorem λ ys b => do
        let val ← Term.elabTermAndSynthesize proof b 
        mkLambdaFVars ys val

      let theoremName := id.getId
        |>.append `arg_
        |>.appendAfter (← constArgSuffix id.getId mainArgIds)
        |>.append propName.getString

      let info : TheoremVal :=
      {
        name := theoremName
        type := normalTheorem
        value := prf
        levelParams := []
      }

      addDecl (.thmDecl info)
      addInstance info.name .local 1000

      -- composition theorem - in the form `FunProp (λ t => e[xᵢ:=yᵢ t])`
      let compTheorem   ← mkCompTheoremFunProp propName spaceName e xs contextVars >>= instantiateMVars

      let compTheoremName := theoremName.appendAfter "'"

      let prf ← forallTelescope compTheorem λ ys b => do
        -- TODO: Fill the proof here!!! 
        -- I think I can manually apply composition rule and then it should be 
        -- automatically discargable by using the normal theorem and product rule
        let val ← Term.elabTermAndSynthesize (← `(by sorry)) b  
        mkLambdaFVars ys val

      let info : TheoremVal :=
      {
        name := compTheoremName
        type := compTheorem
        value := prf
        levelParams := []
      }

      addDecl (.thmDecl info)
      addInstance info.name .local 1000

      addFunctionTheorem id.getId propName mainArgIds ⟨theoremName, compTheoremName⟩

      -- -- For only one main argument we also formulate the theorem in non-compositional manner
      -- -- For example this formulates
      -- --   `IsSmooth λ x => x + y`
      -- -- in addition to 
      -- --   `IsSmooth λ t => (x t) + y` 
      -- if mainArgIds.size = 1 then
      --   let i := mainArgIds.data[0]!
      --   let theoremType ← mkSingleArgFunApp propName e i xs >>= instantiateMVars
        
      --   let prf ← forallTelescope theoremType λ xs b => do
      --     let thrm : Ident := mkIdent theoremName
      --     let prf ← Term.elabTermAndSynthesize (← `(by apply $thrm)) b
      --     mkLambdaFVars xs prf

      --   let info : TheoremVal :=
      --   {
      --     name := theoremName.appendAfter "'"
      --     type := theoremType
      --     value := prf
      --     levelParams := []
      --   }

      --   addDecl (.thmDecl info)
      --   addInstance info.name .local 1000

| `(function_property $id $parms* $[: $retType]? 
    argument $argSpec $assumptions1*
    funTrans $transId $assumptions2* := $Tf by $proof) => do

  Command.liftTermElabM  do

    Term.elabBinders (parms |>.append assumptions1 |>.append assumptions2) λ contextVars => do

      let transName := transId.getId
      -- let propName := propId.getId
      -- let spaceName := spaceId.getId
  
      let argNames : Array Name := argSpec.argSpecNames 

      let explicitArgs := (← contextVars.filterM λ x => do pure (← x.fvarId!.getBinderInfo).isExplicit)
      let e ← mkAppM id.getId explicitArgs
      let args := e.getAppArgs

      let mainArgIds ← argNames.mapM λ name => do
        let idx? ← args.findIdxM? (λ arg => do
          if let .some fvar := arg.fvarId? then
            let name' ← fvar.getUserName
            pure (name' == name)
          else 
            pure false)
        match idx? with
        | some idx => pure idx
        | none => throwError "Specified argument `{name}` is not valid!"

      let xs := mainArgIds.map λ i => args[i]!
      let mainArgIds := mainArgIds.toArraySet

      let targetExpr ← mkTargetExpr transName e xs
      let (compTheorem, prf) ← mkCompTheorem transName e xs targetExpr default contextVars

      IO.println s!"Target expression for `{transName}' is:\n{← ppExpr targetExpr}"

      IO.println s!"Composition theorem for `{transName}' is:\n{← ppExpr compTheorem}"

      forallTelescope compTheorem λ ys b => do

      --   let Tf  ← Term.elabTermAndSynthesize Tf (← inferType b)
      --   let theoremType ← mkEq b Tf
        let prf ← Term.elabTermAndSynthesize proof b

      --   let theoremName := id.getId
      --     |>.append "arg_"
      --     |>.appendAfter (← constArgSuffix id.getId mainArgIds)
      --     |>.append transName.getString
      --     |>.appendAfter "_simp"

      --   let info : TheoremVal :=
      --   {
      --     name := theoremName
      --     type := ← mkForallFVars ys theoremType
      --     value := ← mkLambdaFVars ys prf
      --     levelParams := []
      --   }

      --   addDecl (.thmDecl info)

      --   addFunctionTheorem id.getId transName mainArgIds ⟨theoremName⟩



 
instance {X} [Vec X] : IsSmooth (λ x : X => x) := sorry
instance {X Y} [Vec X] [Vec Y] (x : X): IsSmooth (λ y : Y => x) := sorry
instance {X Y Z} [Vec X] [Vec Y] [Vec Z] (f : Y → Z) (g : X → Y) [IsSmooth f] [IsSmooth g] : IsSmooth (λ x  => f (g x)) := sorry
instance {X Y Z} [Vec X] [Vec Y] [Vec Z] (f : X → Y) (g : X → Z) [IsSmooth f] [IsSmooth g] : IsSmooth (λ x  => (f x, g x)) := sorry

instance {X Y} [Vec X] [Vec Y] (x : X): IsSmooth (λ xy : X×Y => xy.1) := sorry
instance {X Y} [Vec X] [Vec Y] (x : X): IsSmooth (λ xy : X×Y => xy.2) := sorry

theorem diff_comp {X Y Z} [Vec X] [Vec Y] [Vec Z] (f : Y → Z) (g : X → Y) [IsSmooth f] [IsSmooth g]
  : ∂ (λ x => f (g x)) 
    =
    λ x dx => ∂ f (g x) (∂ g x dx) := sorry

theorem diff_prodMk {X Y Z} [Vec X] [Vec Y] [Vec Z] (f : X → Y) (g : X → Z) [IsSmooth f] [IsSmooth g]
  : ∂ (λ x => (f x, g x)) 
    =
    λ x dx => (∂ f x dx, ∂ g x dx) := sorry

instance {X} [SemiHilbert X] : HasAdjDiff (λ x : X => x) := sorry
instance {X Y} [SemiHilbert X] [SemiHilbert Y] (x : X): HasAdjDiff (λ y : Y => x) := sorry

theorem isLin_isSmooth {X Y} [Vec X] [Vec Y] {f : X → Y} [inst : IsLin f] : IsSmooth f := inst.isSmooth
theorem hasAdjoint_on_FinVec {X Y ι κ} {_ : Enumtype ι} {_ : Enumtype κ} [FinVec X ι] [FinVec Y κ] {f : X → Y} [inst : IsLin f] : HasAdjoint f := sorry
theorem hasAdjDiff_on_FinVec {X Y ι κ} {_ : Enumtype ι} {_ : Enumtype κ} [FinVec X ι] [FinVec Y κ] {f : X → Y} [inst : IsSmooth f] : HasAdjDiff f := sorry

syntax " IsSmooth " bracketedBinder* (":=" term)? : argProp
syntax " IsLin " bracketedBinder* (":=" term)? : argProp
syntax " HasAdjoint " bracketedBinder* (":=" term)? : argProp
syntax " HasAdjDiff " bracketedBinder* (":=" term)? : argProp

-- For some reason macro turning just `isSmooth := proof` into `funProp IsSmooth Vec := proof` does not work
macro_rules
-- IsSmooth
| `(function_property $id:ident $parms:bracketedBinder* $[: $retType:term]? 
    argument $argSpec:argSpec $assumptions1*
    IsSmooth $assumptions2* $[:= $proof]?) => do
  let prop : Ident := mkIdent ``IsSmooth
  let space : Ident := mkIdent ``Vec
  let prf := proof.getD (← `(term| by first | (unfold $id; infer_instance) | infer_instance))
  `(function_property $id $parms* $[: $retType:term]? 
    argument $argSpec $assumptions1*
    funProp $prop $space $assumptions2* := $prf)
-- IsLin
| `(function_property $id:ident $parms:bracketedBinder* $[: $retType:term]? 
    argument $argSpec:argSpec  $assumptions1*
    IsLin $extraAssumptions* $[:= $proof]?) => do
  let prop : Ident := mkIdent ``IsLin
  let space : Ident := mkIdent ``Vec
  let prf := proof.getD (← `(term| by first | (unfold $id; infer_instance) | infer_instance))
  `(function_property $id $parms* $[: $retType:term]? 
    argument $argSpec  $assumptions1*
    funProp $prop $space $extraAssumptions* := $prf)
-- HasAdjoint
| `(function_property $id:ident $parms:bracketedBinder* $[: $retType:term]? 
    argument $argSpec:argSpec  $assumptions1*
    HasAdjoint $extraAssumptions* $[:= $proof]?) => do
  let prop : Ident := mkIdent ``HasAdjoint
  let space : Ident := mkIdent ``SemiHilbert
  let prf := proof.getD (← `(term| by first | (unfold $id; infer_instance) | infer_instance))
  `(function_property $id $parms* $[: $retType:term]? 
    argument $argSpec  $assumptions1*
    funProp $prop $space $extraAssumptions* := $prf)
-- HasAdjDiff
| `(function_property $id:ident $parms:bracketedBinder* $[: $retType:term]? 
    argument $argSpec:argSpec  $assumptions1*
    HasAdjDiff $extraAssumptions* $[:= $proof]?) => do
  let prop : Ident := mkIdent ``HasAdjDiff
  let space : Ident := mkIdent ``SemiHilbert
  let prf := proof.getD (← `(term| by first | (unfold $id; infer_instance) | infer_instance))
  `(function_property $id $parms* $[: $retType:term]? 
    argument $argSpec  $assumptions1*
    funProp $prop $space $extraAssumptions* := $prf)

#check Eq.trans

#check uncurryN

example {ι : Type} {_ : Enumtype ι} [FinVec X ι] : FinVec (X×X) (ι⊕ι) := by infer_instance

function_properties HAdd.hAdd {X : Type} (x y : X) : X
argument (x,y) [Vec X]
  IsLin    := sorry,
  IsSmooth := by apply isLin_isSmooth-- ,
--   funTrans SciLean.differential [Vec X] := λ t dt => ∂ x t dt + ∂ y t dt by 
--     by 
--       -- funext t dt
--       -- simp
--       have h : (λ t : T => (x t + y t  : X))
--                =
--                λ t : T => (λ xy : (X×X) => xy.1 + xy.2) ((λ t => (x t, y t)) t) := sorry
--       have : IsSmooth (uncurryN 2 (λ x y : X => x + y)) := sorry
--       -- rw[h]
--       apply Eq.trans (diff_comp (uncurryN 2 (λ x y : X => x + y)) (λ t => (x t, y t))) _
--       simp only [diff_prodMk]
argument (x,y) [SemiHilbert X]
  HasAdjoint := sorry,
  HasAdjDiff := sorry
argument x
  IsSmooth [Vec X] := by simp[uncurryN, Prod.Uncurry.uncurry]; infer_instance,
  HasAdjDiff [SemiHilbert X] := by simp[uncurryN, Prod.Uncurry.uncurry]; infer_instance
argument y
  IsSmooth [Vec X] := by apply HAdd.hAdd.arg_a4a5.IsSmooth',
  HasAdjDiff [SemiHilbert X] := by apply HAdd.hAdd.arg_a4a5.HasAdjDiff'
--   funTrans SciLean.differential [Vec X] := λ t dt => ∂ y t dt by (by funext t dt; simp; admit)

#eval printFunctionTheorems

example {X} [Vec X] (y : X) : IsSmooth λ x : X => x + y := by infer_instance
example {X} [Vec X] (y : X) : IsSmooth λ x : X => y + x := by infer_instance

#check HAdd.hAdd.arg_a4a5.IsSmooth
#check HAdd.hAdd.arg_a4a5.differential_simp
#check HAdd.hAdd.arg_a4.IsSmooth
#check HAdd.hAdd.arg_a5.IsSmooth'
#check HAdd.hAdd.arg_a5.differential_simp


#eval show MetaM Unit from do 
  let info ← getConstInfo ``HAdd.hAdd
  let type := info.type

  forallTelescope type λ xs b => do
    let mut lctx ← getLCtx
    let insts ← getLocalInstances
    lctx := Prod.fst <| xs.foldl (init := (lctx,0)) λ (lctx,i) x =>
      let xId := x.fvarId!
      let name := (lctx.get! xId).userName
      if name.isInternal then
        let name := name.modifyBase λ n => n.appendAfter (toString i)
        (lctx.setUserName xId name, i+1)
      else
        (lctx,i+1)    

    withLCtx lctx (← getLocalInstances) do
      let names ← xs.mapM λ x => x.fvarId!.getUserName
      IO.println s!"Argument names: {names}"
      IO.println s!"Internal names: {names.map λ name => name.isInternal}"
      IO.println s!"Impl detail names: {names.map λ name => name.isImplementationDetail}"


variable (foo : ℝ → ℝ)
#check ∂ foo
