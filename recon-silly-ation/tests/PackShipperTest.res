// SPDX-License-Identifier: PMPL-1.0-or-later
// PackShipperTest - Unit tests for document bundle packaging and distribution
// Tests: pack spec strings, validateManifest, manifestToJson

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
// Tests
// ---------------------------------------------------------------------------

let run = (): (int, int) => {
  Js.Console.log("\n--- PackShipperTest ---")

  // 1. hyperpolymathPackSpec exists and is non-empty
  test("hyperpolymathPackSpec is non-empty", () => {
    assert(
      Js.String2.length(PackShipper.hyperpolymathPackSpec) > 0,
      "hyperpolymath pack spec must exist",
    )
  })

  // 2. hyperpolymathPackSpec contains README requirement
  test("hyperpolymathPackSpec requires README", () => {
    assert(
      Js.String2.includes(PackShipper.hyperpolymathPackSpec, "README"),
      "hyperpolymath pack should require README",
    )
  })

  // 3. minimalPackSpec exists and is non-empty
  test("minimalPackSpec is non-empty", () => {
    assert(
      Js.String2.length(PackShipper.minimalPackSpec) > 0,
      "minimal pack spec must exist",
    )
  })

  // 4. minimalPackSpec contains LICENSE requirement
  test("minimalPackSpec requires LICENSE", () => {
    assert(
      Js.String2.includes(PackShipper.minimalPackSpec, "LICENSE"),
      "minimal pack should require LICENSE",
    )
  })

  // 5. securityPackSpec exists and is non-empty
  test("securityPackSpec is non-empty", () => {
    assert(
      Js.String2.length(PackShipper.securityPackSpec) > 0,
      "security pack spec must exist",
    )
  })

  // 6. securityPackSpec contains SECURITY requirement
  test("securityPackSpec requires SECURITY", () => {
    assert(
      Js.String2.includes(PackShipper.securityPackSpec, "SECURITY"),
      "security pack should require SECURITY",
    )
  })

  // 7. ossPackSpec exists and is non-empty
  test("ossPackSpec is non-empty", () => {
    assert(
      Js.String2.length(PackShipper.ossPackSpec) > 0,
      "OSS pack spec must exist",
    )
  })

  // 8. ossPackSpec contains CODE_OF_CONDUCT
  test("ossPackSpec requires CODE_OF_CONDUCT", () => {
    assert(
      Js.String2.includes(PackShipper.ossPackSpec, "CODE_OF_CONDUCT"),
      "OSS pack should require CODE_OF_CONDUCT",
    )
  })

  // 9. validateManifest returns true for valid manifest
  test("validateManifest returns true for valid manifest", () => {
    let manifest: PackShipper.packManifest = {
      name: "test-pack",
      version: "1.0.0",
      description: "Test",
      author: "Jonathan D.A. Jewell",
      license: "PMPL-1.0-or-later",
      created: Js.Date.now(),
      documents: [],
      validation: {
        packSpec: "minimal",
        validated: true,
        validatedAt: Js.Date.now(),
        errors: [],
        warnings: [],
      },
    }
    assertEqual(PackShipper.validateManifest(manifest), true, "valid manifest should pass")
  })

  // 10. validateManifest returns false for invalid manifest
  test("validateManifest returns false when validated is false", () => {
    let manifest: PackShipper.packManifest = {
      name: "test-pack",
      version: "1.0.0",
      description: "Test",
      author: "Jonathan D.A. Jewell",
      license: "PMPL-1.0-or-later",
      created: Js.Date.now(),
      documents: [],
      validation: {
        packSpec: "minimal",
        validated: false,
        validatedAt: Js.Date.now(),
        errors: ["Missing LICENSE"],
        warnings: [],
      },
    }
    assertEqual(PackShipper.validateManifest(manifest), false, "invalid manifest should fail")
  })

  // 11. manifestToJson produces JSON with name
  test("manifestToJson contains name field", () => {
    let manifest: PackShipper.packManifest = {
      name: "my-bundle",
      version: "2.0.0",
      description: "A test bundle",
      author: "test",
      license: "PMPL-1.0-or-later",
      created: 1000.0,
      documents: [],
      validation: {
        packSpec: "minimal",
        validated: true,
        validatedAt: 1000.0,
        errors: [],
        warnings: [],
      },
    }
    let json = PackShipper.manifestToJson(manifest)
    assert(Js.String2.includes(json, "my-bundle"), "JSON should contain name")
    assert(Js.String2.includes(json, "2.0.0"), "JSON should contain version")
  })

  // 12. manifestToJson contains validation section
  test("manifestToJson contains validation section", () => {
    let manifest: PackShipper.packManifest = {
      name: "test",
      version: "1.0.0",
      description: "",
      author: "",
      license: "PMPL-1.0-or-later",
      created: 1000.0,
      documents: [],
      validation: {
        packSpec: "test",
        validated: true,
        validatedAt: 1000.0,
        errors: [],
        warnings: [],
      },
    }
    let json = PackShipper.manifestToJson(manifest)
    assert(Js.String2.includes(json, "\"validation\""), "JSON should contain validation")
    assert(Js.String2.includes(json, "\"validated\""), "JSON should contain validated field")
  })

  (passed.contents, failed.contents)
}
