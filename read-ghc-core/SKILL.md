---
name: read-ghc-core
description: Read and analyze GHC Core dump-simpl files. Identify loop quality, boxing overhead, monad machinery costs, and lazy knots.
---

# read-ghc-core

Analyze GHC Core (`-ddump-simpl`) to understand what GHC actually compiled your Haskell into. Spot performance problems before they ship.

## When to use this skill

- You have a hot loop and `+RTS -p` shows unexpected allocation
- You're comparing two implementations and one is mysteriously slower
- You're evaluating whether an abstraction (Kleisli, free monad, etc.) has zero-cost or not
- You see `<<loop>>` or non-termination and suspect a strictness issue

## Generating Core dumps

```bash
# For a specific module
cabal build --ghc-options="-ddump-simpl -dsuppress-all -dno-suppress-type-signatures"

# Find the dump file
dist-newstyle/build/*/ghc-*/$PKG-$VERSION/build/src/$Module.dump-simpl
```

Flags explained:
- `-ddump-simpl` — output Core after all optimizations
- `-dsuppress-all` — hide module prefixes, unique IDs, coercions (cleaner)
- `-dno-suppress-type-signatures` — keep types (essential for spotting boxed values)
- `-ddump-to-file` — write to file instead of stdout

## Reading a Core loop

Every hot loop in Core is a recursive function, usually named `$wgo` or `$w$something`. Find it by searching for `Rec {`.

### Step 1: Read the signature

```haskell
$wgo :: Int# -> Addr# -> ForeignPtrContents -> Int# -> [MarkupToken]
```

Check each argument:
- `Int#`, `Addr#`, `Double#`, `Char#` — **unboxed**, good ✓
- `Int`, `ByteString`, `ForeignPtrContents`, tuples — **boxed**, bad ✗

Boxed arguments require heap allocation and pointer chasing per iteration.

### Step 2: Check the loop body

Look for these patterns:

**Good — unboxed args threaded directly:**
```haskell
case ww3 of wild { __DEFAULT ->
  case ww4 of wild1 { __DEFAULT ->
    $wgo (wild +# 1) wild1 ww5 ww6
```

**Bad — heap indirection per iteration:**
```haskell
case s of s1 { (ipv4, ipv5) ->
  case ipv5 of ipv9 -> ...
    $wgo (ipv4, ipv9) ww3 ww4 ww5
```

This is a composite heap tuple. Each iteration:
1. Pattern-matches the tuple
2. Constructs a new tuple for the recursive call
3. Allocates on the heap

**Bad — monad machinery per iteration:**
```haskell
(((runKleisli `cast` ...) (Lexer.WI ipv1 ww3))
  `cast` StateT ... eta)
 `cast` Identity ...
of { (a1, s'1) ->
   case $wgo ... s'1
```

Costs per iteration:
- Kleisli wrapping/unwrapping (coercions)
- StateT/Identity newtype overhead
- State tuple construction and pattern match
- Dictionary lookups if not specialized

### Step 3: Count the allocations

Search for `let` bindings inside the loop body. Each `let` that constructs a data type is a heap allocation.

```haskell
-- Good: no lets inside the loop
$wgo x y = case x of ... -> $wgo (x +# 1) y

-- Bad: allocates a tuple every iteration
$wgo x y = let r = (x +# 1, y) in case r of (a, b) -> $wgo a b
```

## Case studies

### Case 1: State flattening

**Problem:** State carried as a composite tuple.

**Core:**
```haskell
$wgo :: ((Maybe (ByteString -> MarkupToken, Int, Int), OAccState),
         ((ByteClass, Int), MarkupCtx))
      -> Int# -> Addr# -> ForeignPtrContents -> Int# -> [MarkupToken]
```

**Fix:** Flatten state into individual unboxed args:
```haskell
$wgo :: Maybe (ByteString -> MarkupToken) -> Int# -> Int# -> OAccState
      -> ByteClass -> Int# -> MarkupCtx -> Int# -> Addr# -> ForeignPtrContents
      -> Int# -> [MarkupToken]
```

Or use `newtype` wrapping with `UNPACK` pragmas to let GHC do it automatically.

### Case 2: Monad abstraction overhead

**Problem:** `Kleisli (State s)` is 10.9× slower than direct `State`.

**Measurements:**
- `Kleisli tokenize`: 844,000 cycles
- `Traced (->) State tokenize`: 77,400 cycles

**Core (Kleisli version):**
```haskell
$wgo_sj61 :: Int# -> Addr# -> ForeignPtrContents -> Int# -> AccState 
           -> (# [MarkupToken], AccState #)
```

The `AccState` argument is boxed. Every iteration:
1. Monadic bind unwraps StateT
2. Kleisli composition adds coercions
3. Identity transformer is unwrapped
4. State tuple `(# [MarkupToken], AccState #)` is constructed and pattern-matched

**Fix:** Use direct `State` threading:
```haskell
stage2S ((bc, i), acc) = oAccumStep acc (bc, i, oCtx acc)
-- plain function, no monad layer
```

Or specialize the monad stack and add `INLINE`/`SPECIALIZE` pragmas.

### Case 3: Lazy knots and `<<loop>>`

**Problem:** `<<loop>>` — non-termination at runtime.

**Core (-O0):**
```haskell
letrec {
  c0 :: MarkupCtx
  c0 = snd @(...) (s2e s0);

  s0 [Occ=LoopBreaker] :: s1
  s0 = s2i ((undefined @... , i), c0);
} in (s0, s1i (wild, c0))
```

**Analysis:**
- GHC identified a `letrec` group — mutual recursion
- `s0` is marked `LoopBreaker` — GHC's chosen evaluation point
- `c0` depends on `s0`, `s0` depends on `c0`
- This is a lazy knot: fine if laziness is preserved, deadly if someone forces `s0` before `c0` is available

**Fix:** Add strictness. Either:
- `seq` the recursive bindings in the right order
- Use `{-# INLINE #-}` to let GHC inline the knot away
- Restructure to avoid mutual recursion

## Quick reference: Core patterns

| Pattern | Meaning | Verdict |
|---------|---------|---------|
| `Int#`, `Addr#`, `Double#` | Unboxed machine integer/pointer/float | ✓ Good |
| `Int`, `ByteString`, `Maybe a` | Boxed heap object | ✗ Check if necessary |
| `case x of { __DEFAULT -> ... }` | Unboxed scrutinee, no heap alloc | ✓ Good |
| `case s of (a, b) -> ...` | Tuple deconstruction | ⚠️ Check if s is reboxed |
| `let r = (a, b) in ...` | Heap allocation inside loop | ✗ Bad if in hot loop |
| `Rec { $wgo ... }` | Recursive loop | — Analyze body |
| `cast` | Type coercion (usually free at runtime) | ✓ Usually free |
| `StateT` / `Identity` / `Kleisli` | Monad transformer layers | ⚠️ Check specialization |
| `LoopBreaker` | GHC's chosen strict evaluation point | — Understand why |

## Workflow

1. **Profile first** — `+RTS -p -hy` to confirm where time/allocations are
2. **Generate Core** — `-ddump-simpl` for the hot module
3. **Find the loop** — search for `Rec {` and the `$wgo` function
4. **Check signature** — count boxed vs unboxed args
5. **Read the body** — look for heap allocations, monad layers, coercions
6. **Compare versions** — generate Core for both implementations, diff the loops
7. **Fix and verify** — change code, regenerate Core, confirm the pattern changed

## Anti-patterns

**Don't** read Core for every function. It's noisy. Focus on:
- Functions at the top of `-p` profiling output
- Functions you suspect are allocating unexpectedly
- Abstraction boundaries (generic monad code, free constructions)

**Don't** trust `-O0` Core for performance analysis. Always use `-O2` (or cabal's default).

**Don't** chase unboxing into user-visible types. Unbox at the loop boundary; keep nice types in the API.
