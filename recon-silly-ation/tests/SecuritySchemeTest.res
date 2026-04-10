// SPDX-License-Identifier: PMPL-1.0-or-later
// SecuritySchemeTest - Unit tests for security scheme types
// Note: No SecurityScheme module exists yet; tests focus on type construction
// and expected security context defaults using inline types.

open Types

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

let passed = ref(0)
let failed = ref(0)

let test = (name: string, fn: unit => unit): unit => {
  try {
    fn()
    passed := passed.contents + 1
    Js.Console.log(`  PASS ${name}`)
  } catch {
  | _ => {
      failed := failed.contents + 1
      Js.Console.error(`  FAIL ${name}`)
    }
  }
}

let assert = (cond: bool, msg: string): unit => {
  if !cond {
    Js.Exn.raiseError(msg)
  }
}

let assertEqual = (a: 'a, b: 'a, msg: string): unit => {
  if a != b {
    Js.Exn.raiseError(msg)
  }
}

// ---------------------------------------------------------------------------
// Inline types (SecurityScheme module does not exist yet)
// ---------------------------------------------------------------------------

type hashAlgorithm =
  | SHA256
  | SHA384
  | SHA512

type signatureScheme =
  | Ed25519
  | RSA4096

type securityContext = {
  hashAlgorithm: hashAlgorithm,
  signatureScheme: signatureScheme,
  requireSigned: bool,
  minHashLength: int,
  allowedAlgorithms: array<hashAlgorithm>,
}

let defaultSecurityContext: securityContext = {
  hashAlgorithm: SHA256,
  signatureScheme: Ed25519,
  requireSigned: true,
  minHashLength: 64,
  allowedAlgorithms: [SHA256, SHA384, SHA512],
}

let algorithmToString = (alg: hashAlgorithm): string => {
  switch alg {
  | SHA256 => "sha256"
  | SHA384 => "sha384"
  | SHA512 => "sha512"
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- SecuritySchemeTest ---")

  // 1. defaultSecurityContext hashAlgorithm
  test("defaultSecurityContext uses SHA256", () => {
    assertEqual(defaultSecurityContext.hashAlgorithm, SHA256, "default hash should be SHA256")
  })

  // 2. defaultSecurityContext signatureScheme
  test("defaultSecurityContext uses Ed25519", () => {
    assertEqual(
      defaultSecurityContext.signatureScheme,
      Ed25519,
      "default signature should be Ed25519",
    )
  })

  // 3. defaultSecurityContext requireSigned
  test("defaultSecurityContext requireSigned is true", () => {
    assertEqual(defaultSecurityContext.requireSigned, true, "require signed should be true")
  })

  // 4. defaultSecurityContext minHashLength
  test("defaultSecurityContext minHashLength is 64", () => {
    assertEqual(defaultSecurityContext.minHashLength, 64, "min hash length should be 64")
  })

  // 5. defaultSecurityContext allowedAlgorithms
  test("defaultSecurityContext has 3 allowed algorithms", () => {
    assertEqual(
      Belt.Array.length(defaultSecurityContext.allowedAlgorithms),
      3,
      "should have 3 allowed algorithms",
    )
  })

  // 6. algorithmToString SHA256
  test("algorithmToString SHA256 returns sha256", () => {
    assertEqual(algorithmToString(SHA256), "sha256", "SHA256 -> sha256")
  })

  // 7. algorithmToString SHA384
  test("algorithmToString SHA384 returns sha384", () => {
    assertEqual(algorithmToString(SHA384), "sha384", "SHA384 -> sha384")
  })

  // 8. algorithmToString SHA512
  test("algorithmToString SHA512 returns sha512", () => {
    assertEqual(algorithmToString(SHA512), "sha512", "SHA512 -> sha512")
  })

  // 9. type construction securityContext
  test("securityContext can be constructed with custom values", () => {
    let ctx: securityContext = {
      hashAlgorithm: SHA512,
      signatureScheme: RSA4096,
      requireSigned: false,
      minHashLength: 128,
      allowedAlgorithms: [SHA512],
    }
    assertEqual(ctx.hashAlgorithm, SHA512, "custom hash algorithm")
    assertEqual(ctx.requireSigned, false, "custom requireSigned")
    assertEqual(ctx.minHashLength, 128, "custom minHashLength")
  })

  // 10. signatureScheme Ed25519 vs RSA4096
  test("signatureScheme variants are distinct", () => {
    assert(Ed25519 != RSA4096, "Ed25519 and RSA4096 should be distinct")
  })

  (passed.contents, failed.contents)
}
