-- SPDX-License-Identifier: MPL-2.0
-- Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
||| Typed ABI contract for the repo-batcher FFI boundary (Layer 6).
|||
||| This is the formal companion to src/ats2/ffi/c_exports.dats (Layer 5).
||| It pins down, in Idris2 0.8.0, the SHAPE and INVARIANTS of every
||| value that crosses the C boundary into the Zig CLI (Layer 7):
|||
|||   1. The operation selector is a closed enum, not string dispatch,
|||      and its Int encoding is total and injective (proved).
|||   2. dry_run / backup flags are exactly {0,1} (a refined Bit).
|||   3. A BatchResult's three counts are Nats and its `total` is their
|||      sum (proved by construction); the C struct mirrors this.
|||
||| HONESTY NOTE: this module proves properties of the DATA CONTRACT
||| only. It does NOT and cannot prove that the ATS2 side or git/gh did
||| the right thing — that is an external effect (see effects.sats).
||| The ABI contract's job is to make the boundary total and
||| machine-checked, which it does.
module Abi

import Data.Nat
import Decidable.Equality

%default total

-- ═══════════════════════════════════════════════════════════════════
-- Operation selector (closed enum, no string dispatch)
-- ═══════════════════════════════════════════════════════════════════

||| Every C entry point in c_exports.dats, as a closed type.
public export
data Op
  = GetVersion
  | ValidateSpdx
  | GitSync
  | LicenseUpdate
  | FileReplace
  | SpdxAudit

||| Total encoding to the C-side int tag.
public export
opToInt : Op -> Int
opToInt GetVersion    = 0
opToInt ValidateSpdx  = 1
opToInt GitSync       = 2
opToInt LicenseUpdate = 3
opToInt FileReplace   = 4
opToInt SpdxAudit     = 5

||| Total decoding; round-trips opToInt for all constructors.
public export
opFromInt : Int -> Maybe Op
opFromInt 0 = Just GetVersion
opFromInt 1 = Just ValidateSpdx
opFromInt 2 = Just GitSync
opFromInt 3 = Just LicenseUpdate
opFromInt 4 = Just FileReplace
opFromInt 5 = Just SpdxAudit
opFromInt _ = Nothing

||| opFromInt . opToInt = Just  (encoding is injective / lossless).
||| Proved by exhaustive case analysis — `Refl` per constructor.
public export
opRoundTrip : (o : Op) -> opFromInt (opToInt o) = Just o
opRoundTrip GetVersion    = Refl
opRoundTrip ValidateSpdx  = Refl
opRoundTrip GitSync       = Refl
opRoundTrip LicenseUpdate = Refl
opRoundTrip FileReplace   = Refl
opRoundTrip SpdxAudit     = Refl

-- ═══════════════════════════════════════════════════════════════════
-- Boundary flags: exactly {0,1}
-- ═══════════════════════════════════════════════════════════════════

||| A C int constrained to the boolean domain the ABI actually uses.
public export
data Bit = O | I

public export
bitToInt : Bit -> Int
bitToInt O = 0
bitToInt I = 1

||| The C side reads `dry_run == 1`; this mirrors that decision exactly.
public export
isSet : Bit -> Bool
isSet O = False
isSet I = True

public export
bitConsistent : (b : Bit) -> (bitToInt b == 1) = isSet b
bitConsistent O = Refl
bitConsistent I = Refl

-- ═══════════════════════════════════════════════════════════════════
-- BatchResult: the c_batch_result struct, with a proved total
-- ═══════════════════════════════════════════════════════════════════

||| Mirrors `typedef c_batch_result = @{ success,failure,skipped:int }`.
||| Counts are Nats (the C side only ever writes >= 0). `total` is the
||| sum, guaranteed equal to success+failure+skipped BY CONSTRUCTION.
public export
record BatchResult where
  constructor MkBatch
  success : Nat
  failure : Nat
  skipped : Nat

public export
total' : BatchResult -> Nat
total' (MkBatch s f k) = s + f + k

||| Empty result is the additive identity (0 total). Proved.
public export
emptyBatchTotalZero : total' (MkBatch 0 0 0) = 0
emptyBatchTotalZero = Refl

||| Recording one more success increments success and the total by 1.
||| Proved (this is the invariant batch_add must preserve on the ATS
||| side; here it is a theorem about the contract).
public export
addSuccess : BatchResult -> BatchResult
addSuccess (MkBatch s f k) = MkBatch (S s) f k

public export
addSuccessTotal : (b : BatchResult) ->
                  total' (addSuccess b) = S (total' b)
addSuccessTotal (MkBatch s f k) = Refl

-- ═══════════════════════════════════════════════════════════════════
-- C ABI exports (the actual boundary functions)
-- ═══════════════════════════════════════════════════════════════════

export
abiOpToInt : Op -> Int
abiOpToInt = opToInt

export
abiBitToInt : Bit -> Int
abiBitToInt = bitToInt
