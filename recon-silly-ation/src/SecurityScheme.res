// SPDX-License-Identifier: PMPL-1.0-or-later
// SecurityScheme - Post-quantum cryptographic security scheme
// Defines algorithms, key types, and WASM bindings for the
// recon-silly-ation document reconciliation system.
//
// Algorithm selections follow NIST PQC standards (FIPS 203/204/205)
// with classical fallbacks for transition period.

open Types

// =============================================================================
// Hash Algorithm Types
// =============================================================================

// Hash algorithms for content integrity and password storage.
// SHAKE3-512 is the general-purpose default (NIST SP 800-185).
// BLAKE3 is optimised for database content-addressable storage.
// Argon2id is the mandatory choice for password/secret hashing.
type hashAlgorithm =
  | SHAKE3_512 // General-purpose (Keccak-based, 512-bit output)
  | BLAKE3 // Database content hashing (parallelisable, 256-bit)
  | Argon2id // Password hashing (memory-hard, side-channel resistant)

// =============================================================================
// Signature Algorithm Types
// =============================================================================

// Digital signature algorithms for document signing and verification.
// Dilithium5-AES is the primary post-quantum choice (FIPS 204 / ML-DSA-87).
// Ed448 provides classical fallback (RFC 8032, 448-bit Edwards curve).
// Hybrid combines PQ + classical for defence-in-depth.
// SPHINCS+ is the stateless hash-based backup (FIPS 205 / SLH-DSA).
type signatureAlgorithm =
  | Dilithium5_AES // ML-DSA-87 (FIPS 204), lattice-based, AES variant
  | Ed448 // Classical fallback, 224-bit security level
  | Hybrid(signatureAlgorithm, signatureAlgorithm) // Combined PQ + classical
  | SPHINCS_Plus // SLH-DSA (FIPS 205), stateless hash-based backup

// =============================================================================
// Key Exchange Algorithm Types
// =============================================================================

// Key encapsulation mechanisms for establishing shared secrets.
// Kyber1024 is the sole choice (FIPS 203 / ML-KEM-1024, NIST Level 5).
type keyExchangeAlgorithm =
  | Kyber1024 // ML-KEM-1024 (FIPS 203), lattice-based, 256-bit shared secret

// =============================================================================
// Symmetric Encryption Algorithm Types
// =============================================================================

// Symmetric authenticated encryption for document content at rest.
// XChaCha20-Poly1305 with 256-bit keys: extended nonce (192-bit),
// immune to timing attacks, no AES-NI requirement.
type symmetricAlgorithm =
  | XChaCha20Poly1305_256 // 256-bit key, 192-bit nonce, AEAD

// =============================================================================
// Key Derivation Function Types
// =============================================================================

// Key derivation functions for expanding keying material.
// HKDF with SHAKE-512 provides domain separation and key expansion.
type kdfAlgorithm =
  | HKDF_SHAKE512 // HKDF (RFC 5869) with SHAKE-512 as underlying PRF

// =============================================================================
// Random Number Generator Types
// =============================================================================

// Deterministic random bit generators for key generation.
// ChaCha20-DRBG provides backtracking resistance and fast performance.
type rngAlgorithm =
  | ChaCha20_DRBG // ChaCha20-based DRBG, 256-bit seed

// =============================================================================
// Transport Protocol Types
// =============================================================================

// Network transport protocols for inter-component communication.
// IPv6-only eliminates NAT traversal overhead and dual-stack complexity.
// QUIC provides multiplexed, encrypted transport (RFC 9000).
// HTTP/3 runs over QUIC for application-layer interchange.
type transportProtocol =
  | IPv6Only // Mandatory IPv6, no IPv4 fallback
  | QUIC // RFC 9000, UDP-based multiplexed transport
  | HTTP3 // RFC 9114, HTTP over QUIC

// =============================================================================
// Accessibility (WCAG) Compliance Report
// =============================================================================

// Report structure for WCAG 2.2 AAA compliance of generated documents.
// Every reconciled document must pass accessibility validation.
type accessibilityReport = {
  level: string, // Target level: "AAA" (always AAA)
  score: float, // Compliance score 0.0 - 1.0
  issues: array<string>, // List of WCAG violations found
}

// =============================================================================
// Security Context
// =============================================================================

// Aggregate record holding the active algorithm suite for a session.
// Passed through the reconciliation pipeline so every stage uses
// consistent cryptographic primitives.
type securityContext = {
  hashAlgo: hashAlgorithm,
  signatureAlgo: signatureAlgorithm,
  keyExchangeAlgo: keyExchangeAlgorithm,
  symmetricAlgo: symmetricAlgorithm,
  kdfAlgo: kdfAlgorithm,
  rngAlgo: rngAlgorithm,
  transport: transportProtocol,
}

// Return the strongest-defaults security context.
// Uses Hybrid(Dilithium5_AES, Ed448) for defence-in-depth signatures.
let defaultSecurityContext = (): securityContext => {
  hashAlgo: SHAKE3_512,
  signatureAlgo: Hybrid(Dilithium5_AES, Ed448),
  keyExchangeAlgo: Kyber1024,
  symmetricAlgo: XChaCha20Poly1305_256,
  kdfAlgo: HKDF_SHAKE512,
  rngAlgo: ChaCha20_DRBG,
  transport: HTTP3,
}

// =============================================================================
// Signed Document
// =============================================================================

// A document with a cryptographic signature attached.
// Used for tamper-evident reconciliation artefacts.
type signedDocument = {
  content: string, // Raw document content
  signature: string, // Hex-encoded signature bytes
  signerPublicKey: string, // Hex-encoded public key of signer
  algorithm: signatureAlgorithm, // Algorithm used to produce the signature
  timestamp: float, // Unix timestamp of signing
}

// =============================================================================
// Key Pair
// =============================================================================

// Asymmetric key pair for signature or key-exchange operations.
// Keys are represented as hex-encoded strings.
type keyPair = {
  publicKey: string, // Hex-encoded public key
  privateKey: string, // Hex-encoded private key (MUST be protected)
  algorithm: signatureAlgorithm, // Algorithm this key pair is valid for
}

// =============================================================================
// WASM External Bindings
// =============================================================================
// These map to functions exported by the Rust WASM module
// (wasm-modules/src/security.rs).  The WASM module must be
// initialised before calling any of these.

@module("../wasm-modules/pkg/recon_wasm") @val
external shake3_512_hash: string => string = "shake3_512_hash"

@module("../wasm-modules/pkg/recon_wasm") @val
external blake3_hash: string => string = "blake3_hash"

@module("../wasm-modules/pkg/recon_wasm") @val
external dilithium5_sign: (string, string) => string = "dilithium5_sign"

@module("../wasm-modules/pkg/recon_wasm") @val
external dilithium5_verify: (string, string, string) => bool = "dilithium5_verify"

@module("../wasm-modules/pkg/recon_wasm") @val
external kyber1024_keygen: unit => Js.Json.t = "kyber1024_keygen"

// =============================================================================
// Algorithm-to-String Conversions
// =============================================================================

// Convert a hashAlgorithm variant to its canonical string representation.
let hashAlgorithmToString = (algo: hashAlgorithm): string => {
  switch algo {
  | SHAKE3_512 => "SHAKE3-512"
  | BLAKE3 => "BLAKE3"
  | Argon2id => "Argon2id"
  }
}

// Convert a signatureAlgorithm variant to its canonical string representation.
// Hybrid algorithms are rendered as "Hybrid(inner + inner)".
let rec signatureAlgorithmToString = (algo: signatureAlgorithm): string => {
  switch algo {
  | Dilithium5_AES => "ML-DSA-87 (Dilithium5-AES)"
  | Ed448 => "Ed448"
  | Hybrid(primary, secondary) =>
    `Hybrid(${signatureAlgorithmToString(primary)} + ${signatureAlgorithmToString(secondary)})`
  | SPHINCS_Plus => "SLH-DSA (SPHINCS+)"
  }
}

// Convert a keyExchangeAlgorithm variant to its canonical string representation.
let keyExchangeAlgorithmToString = (algo: keyExchangeAlgorithm): string => {
  switch algo {
  | Kyber1024 => "ML-KEM-1024 (Kyber1024)"
  }
}

// Convert a symmetricAlgorithm variant to its canonical string representation.
let symmetricAlgorithmToString = (algo: symmetricAlgorithm): string => {
  switch algo {
  | XChaCha20Poly1305_256 => "XChaCha20-Poly1305-256"
  }
}

// Convert a kdfAlgorithm variant to its canonical string representation.
let kdfAlgorithmToString = (algo: kdfAlgorithm): string => {
  switch algo {
  | HKDF_SHAKE512 => "HKDF-SHAKE512"
  }
}

// Convert an rngAlgorithm variant to its canonical string representation.
let rngAlgorithmToString = (algo: rngAlgorithm): string => {
  switch algo {
  | ChaCha20_DRBG => "ChaCha20-DRBG"
  }
}

// Convert a transportProtocol variant to its canonical string representation.
let transportProtocolToString = (proto: transportProtocol): string => {
  switch proto {
  | IPv6Only => "IPv6-Only"
  | QUIC => "QUIC (RFC 9000)"
  | HTTP3 => "HTTP/3 (RFC 9114)"
  }
}

// =============================================================================
// Hash Dispatch Helper
// =============================================================================

// Hash a string using the specified algorithm.
// Routes to the appropriate WASM binding.
// NOTE: Argon2id requires a salt and is not supported here;
// use the dedicated WASM function argon2id_hash(input, salt) instead.
let hashWithAlgorithm = (algo: hashAlgorithm, input: string): string => {
  switch algo {
  | SHAKE3_512 => shake3_512_hash(input)
  | BLAKE3 => blake3_hash(input)
  | Argon2id =>
    // Argon2id requires a salt parameter - callers must use the
    // WASM binding argon2id_hash(input, salt) directly.
    Js.Exn.raiseError(
      "Argon2id requires a salt parameter. Use the WASM binding argon2id_hash(input, salt) directly.",
    )
  }
}

// =============================================================================
// User-Friendly Hash Name (Placeholder)
// =============================================================================

// Convert a hex-encoded hash digest to a human-readable name.
// Concept: map pairs of hex bytes to words from a curated wordlist,
// then encode in Base32 for display. This makes hashes recognisable
// in reconciliation reports without needing to compare raw hex.
//
// Current implementation is a placeholder that returns a truncated
// Base32-style representation. The real implementation will live in
// the WASM module (user_friendly_hash_name) and use a proper wordlist
// derived from the EFF large wordlist.
let userFriendlyHashName = (hexHash: string): string => {
  // Placeholder: take the first 10 hex characters and prefix with "doc-"
  // to give a short, somewhat-recognisable identifier.
  // Real implementation: WASM-side Base32 encoding -> wordlist mapping.
  let prefix = Js.String2.slice(hexHash, ~from=0, ~to_=10)
  `doc-${prefix}`
}

// =============================================================================
// Security Context Serialisation
// =============================================================================

// Serialise a securityContext to JSON for transport/storage.
let securityContextToJson = (ctx: securityContext): Js.Json.t => {
  Js.Json.object_(
    Js.Dict.fromArray([
      ("hashAlgo", Js.Json.string(hashAlgorithmToString(ctx.hashAlgo))),
      ("signatureAlgo", Js.Json.string(signatureAlgorithmToString(ctx.signatureAlgo))),
      ("keyExchangeAlgo", Js.Json.string(keyExchangeAlgorithmToString(ctx.keyExchangeAlgo))),
      ("symmetricAlgo", Js.Json.string(symmetricAlgorithmToString(ctx.symmetricAlgo))),
      ("kdfAlgo", Js.Json.string(kdfAlgorithmToString(ctx.kdfAlgo))),
      ("rngAlgo", Js.Json.string(rngAlgorithmToString(ctx.rngAlgo))),
      ("transport", Js.Json.string(transportProtocolToString(ctx.transport))),
    ]),
  )
}

// Serialise a signedDocument to JSON for storage or transmission.
let signedDocumentToJson = (doc: signedDocument): Js.Json.t => {
  Js.Json.object_(
    Js.Dict.fromArray([
      ("content", Js.Json.string(doc.content)),
      ("signature", Js.Json.string(doc.signature)),
      ("signerPublicKey", Js.Json.string(doc.signerPublicKey)),
      ("algorithm", Js.Json.string(signatureAlgorithmToString(doc.algorithm))),
      ("timestamp", Js.Json.number(doc.timestamp)),
    ]),
  )
}

// Serialise an accessibilityReport to JSON.
let accessibilityReportToJson = (report: accessibilityReport): Js.Json.t => {
  Js.Json.object_(
    Js.Dict.fromArray([
      ("level", Js.Json.string(report.level)),
      ("score", Js.Json.number(report.score)),
      (
        "issues",
        Js.Json.array(report.issues->Belt.Array.map(Js.Json.string)),
      ),
    ]),
  )
}

// =============================================================================
// Factory Helpers
// =============================================================================

// Create an empty accessibility report at AAA level.
let emptyAccessibilityReport = (): accessibilityReport => {
  level: "AAA",
  score: 1.0,
  issues: [],
}

// Create a signed document (delegates actual signing to WASM).
let createSignedDocument = (
  content: string,
  privateKey: string,
  publicKey: string,
  algo: signatureAlgorithm,
): signedDocument => {
  let signature = switch algo {
  | Dilithium5_AES => dilithium5_sign(content, privateKey)
  | Hybrid(Dilithium5_AES, _secondary) =>
    // In hybrid mode, produce the primary (PQ) signature.
    // A full implementation would concatenate both signatures.
    dilithium5_sign(content, privateKey)
  | Ed448 =>
    // Ed448 signing would call a separate WASM binding (not yet wired).
    Js.Exn.raiseError("Ed448 WASM binding not yet implemented")
  | SPHINCS_Plus =>
    Js.Exn.raiseError("SPHINCS+ WASM binding not yet implemented")
  | Hybrid(_, _) =>
    Js.Exn.raiseError("Unsupported hybrid signature combination")
  }

  {
    content,
    signature,
    signerPublicKey: publicKey,
    algorithm: algo,
    timestamp: Js.Date.now(),
  }
}

// Verify a signed document (delegates actual verification to WASM).
let verifySignedDocument = (doc: signedDocument): bool => {
  switch doc.algorithm {
  | Dilithium5_AES => dilithium5_verify(doc.content, doc.signature, doc.signerPublicKey)
  | Hybrid(Dilithium5_AES, _secondary) =>
    // Verify primary (PQ) signature.  Full implementation would
    // verify both and require both to pass.
    dilithium5_verify(doc.content, doc.signature, doc.signerPublicKey)
  | Ed448 => false // Not yet implemented
  | SPHINCS_Plus => false // Not yet implemented
  | Hybrid(_, _) => false // Unsupported combination
  }
}
