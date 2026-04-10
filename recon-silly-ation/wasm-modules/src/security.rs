// SPDX-License-Identifier: PMPL-1.0-or-later
//
// security.rs - Post-quantum cryptographic primitives for recon-silly-ation
//
// This module provides WASM-exported stub functions for post-quantum
// and modern cryptographic operations.  Each function is annotated with
// the algorithm it will implement and what crate/library the real
// implementation should use.
//
// Current state: stubs that return placeholder values.  The signatures
// are stable and match the ReScript external bindings in
// src/SecurityScheme.res.
//
// Real implementations will require the following crates (not yet in
// Cargo.toml — add them when moving beyond stubs):
//   - sha3           (SHAKE3-512, Keccak)
//   - blake3         (BLAKE3)
//   - argon2         (Argon2id)
//   - pqcrypto-dilithium  (ML-DSA-87 / Dilithium5)
//   - pqcrypto-kem        (ML-KEM-1024 / Kyber1024)
//   - chacha20poly1305    (XChaCha20-Poly1305)
//   - hkdf                (HKDF key derivation)
//   - rand_chacha         (ChaCha20-DRBG)

use wasm_bindgen::prelude::*;

// =============================================================================
// Hash Functions
// =============================================================================

/// Compute a SHAKE3-512 (Keccak XOF) digest of the input.
///
/// Real implementation: use the `sha3` crate's `Shake256` (or a
/// SHAKE3 wrapper once standardised).  Output should be 512 bits
/// (64 bytes), hex-encoded.
#[wasm_bindgen]
pub fn shake3_512_hash(input: &str) -> String {
    // TODO: Replace with real SHAKE3-512 via the sha3 crate.
    //   use sha3::{Shake256, digest::{Update, ExtendableOutput, XofReader}};
    //   let mut hasher = Shake256::default();
    //   hasher.update(input.as_bytes());
    //   let mut reader = hasher.finalize_xof();
    //   let mut output = [0u8; 64];
    //   reader.read(&mut output);
    //   hex::encode(output)
    format!("stub:shake3_512:{}", hex_stub(input))
}

/// Compute a BLAKE3 digest of the input.
///
/// Real implementation: use the `blake3` crate.  Output is 256 bits
/// (32 bytes), hex-encoded.  BLAKE3 is used for database content
/// hashing because it is parallelisable and extremely fast.
#[wasm_bindgen]
pub fn blake3_hash(input: &str) -> String {
    // TODO: Replace with real BLAKE3 via the blake3 crate.
    //   let hash = blake3::hash(input.as_bytes());
    //   hash.to_hex().to_string()
    format!("stub:blake3:{}", hex_stub(input))
}

/// Compute an Argon2id hash of the input with the given salt.
///
/// Real implementation: use the `argon2` crate with Argon2id variant,
/// memory cost 64 MiB, time cost 3, parallelism 4.  Output is the
/// PHC-format string ($argon2id$v=19$...).
#[wasm_bindgen]
pub fn argon2id_hash(input: &str, salt: &str) -> String {
    // TODO: Replace with real Argon2id via the argon2 crate.
    //   use argon2::{Argon2, Algorithm, Version, Params, PasswordHasher};
    //   let params = Params::new(65536, 3, 4, Some(32)).unwrap();
    //   let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    //   let salt_obj = argon2::password_hash::SaltString::from_b64(salt).unwrap();
    //   let hash = argon2.hash_password(input.as_bytes(), &salt_obj).unwrap();
    //   hash.to_string()
    format!("stub:argon2id:{}:{}", hex_stub(input), hex_stub(salt))
}

// =============================================================================
// Dilithium5 / ML-DSA-87 (FIPS 204) — Digital Signatures
// =============================================================================

/// Generate a Dilithium5-AES (ML-DSA-87) key pair.
///
/// Returns a JSON object: { "public_key": "<hex>", "private_key": "<hex>" }
///
/// Real implementation: use `pqcrypto-dilithium` crate's `keypair()`
/// function.  Public key is 2592 bytes, private key is 4864 bytes.
#[wasm_bindgen]
pub fn dilithium5_keygen() -> JsValue {
    // TODO: Replace with real Dilithium5 key generation.
    //   use pqcrypto_dilithium::dilithium5aes;
    //   let (pk, sk) = dilithium5aes::keypair();
    //   return JSON with hex-encoded keys
    let json = serde_json::json!({
        "public_key": "stub:dilithium5:public_key:0000",
        "private_key": "stub:dilithium5:private_key:0000"
    });
    JsValue::from_str(&json.to_string())
}

/// Sign a message using Dilithium5-AES (ML-DSA-87).
///
/// Returns the hex-encoded signature (4627 bytes for Dilithium5).
///
/// Real implementation: use `pqcrypto_dilithium::dilithium5aes::detached_sign`.
#[wasm_bindgen]
pub fn dilithium5_sign(message: &str, private_key: &str) -> String {
    // TODO: Replace with real Dilithium5 signing.
    //   use pqcrypto_dilithium::dilithium5aes;
    //   let sk = dilithium5aes::SecretKey::from_bytes(hex::decode(private_key)?)?;
    //   let sig = dilithium5aes::detached_sign(message.as_bytes(), &sk);
    //   hex::encode(sig.as_bytes())
    let _ = private_key; // Suppress unused warning
    format!("stub:dilithium5_sig:{}", hex_stub(message))
}

/// Verify a Dilithium5-AES (ML-DSA-87) signature.
///
/// Returns true if the signature is valid for the given message and
/// public key.
///
/// Real implementation: use `pqcrypto_dilithium::dilithium5aes::verify_detached_signature`.
#[wasm_bindgen]
pub fn dilithium5_verify(message: &str, signature: &str, public_key: &str) -> bool {
    // TODO: Replace with real Dilithium5 verification.
    //   use pqcrypto_dilithium::dilithium5aes;
    //   let pk = dilithium5aes::PublicKey::from_bytes(hex::decode(public_key)?)?;
    //   let sig = dilithium5aes::DetachedSignature::from_bytes(hex::decode(signature)?)?;
    //   dilithium5aes::verify_detached_signature(&sig, message.as_bytes(), &pk).is_ok()
    let _ = (message, signature, public_key);
    false // Stub always returns false — real impl verifies the signature
}

// =============================================================================
// Kyber1024 / ML-KEM-1024 (FIPS 203) — Key Encapsulation
// =============================================================================

/// Generate a Kyber1024 (ML-KEM-1024) key pair.
///
/// Returns JSON: { "public_key": "<hex>", "private_key": "<hex>" }
///
/// Real implementation: use `pqcrypto_kem::kyber1024::keypair()`.
/// Public key is 1568 bytes, private key is 3168 bytes.
#[wasm_bindgen]
pub fn kyber1024_keygen() -> JsValue {
    // TODO: Replace with real Kyber1024 key generation.
    //   use pqcrypto_kem::kyber1024;
    //   let (pk, sk) = kyber1024::keypair();
    //   return JSON with hex-encoded keys
    let json = serde_json::json!({
        "public_key": "stub:kyber1024:public_key:0000",
        "private_key": "stub:kyber1024:private_key:0000"
    });
    JsValue::from_str(&json.to_string())
}

/// Encapsulate a shared secret using a Kyber1024 public key.
///
/// Returns JSON: { "ciphertext": "<hex>", "shared_secret": "<hex>" }
/// The shared secret is 32 bytes.  The ciphertext is 1568 bytes.
///
/// Real implementation: use `pqcrypto_kem::kyber1024::encapsulate`.
#[wasm_bindgen]
pub fn kyber1024_encapsulate(public_key: &str) -> JsValue {
    // TODO: Replace with real Kyber1024 encapsulation.
    //   use pqcrypto_kem::kyber1024;
    //   let pk = kyber1024::PublicKey::from_bytes(hex::decode(public_key)?)?;
    //   let (ss, ct) = kyber1024::encapsulate(&pk);
    //   return JSON with hex-encoded ciphertext and shared_secret
    let _ = public_key;
    let json = serde_json::json!({
        "ciphertext": "stub:kyber1024:ciphertext:0000",
        "shared_secret": "stub:kyber1024:shared_secret:0000"
    });
    JsValue::from_str(&json.to_string())
}

/// Decapsulate a shared secret from a Kyber1024 ciphertext.
///
/// Returns the hex-encoded 32-byte shared secret.
///
/// Real implementation: use `pqcrypto_kem::kyber1024::decapsulate`.
#[wasm_bindgen]
pub fn kyber1024_decapsulate(ciphertext: &str, private_key: &str) -> String {
    // TODO: Replace with real Kyber1024 decapsulation.
    //   use pqcrypto_kem::kyber1024;
    //   let sk = kyber1024::SecretKey::from_bytes(hex::decode(private_key)?)?;
    //   let ct = kyber1024::Ciphertext::from_bytes(hex::decode(ciphertext)?)?;
    //   let ss = kyber1024::decapsulate(&ct, &sk);
    //   hex::encode(ss.as_bytes())
    let _ = (ciphertext, private_key);
    "stub:kyber1024:shared_secret:0000".to_string()
}

// =============================================================================
// XChaCha20-Poly1305-256 — Symmetric AEAD
// =============================================================================

/// Encrypt plaintext using XChaCha20-Poly1305 with a 256-bit key.
///
/// The nonce must be 192 bits (24 bytes), hex-encoded.
/// Returns hex-encoded ciphertext with appended Poly1305 tag (16 bytes).
///
/// Real implementation: use the `chacha20poly1305` crate's `XChaCha20Poly1305`.
#[wasm_bindgen]
pub fn xchacha20poly1305_encrypt(plaintext: &str, key: &str, nonce: &str) -> String {
    // TODO: Replace with real XChaCha20-Poly1305 encryption.
    //   use chacha20poly1305::{XChaCha20Poly1305, Key, XNonce, aead::Aead, KeyInit};
    //   let cipher_key = Key::from_slice(&hex::decode(key)?);
    //   let cipher_nonce = XNonce::from_slice(&hex::decode(nonce)?);
    //   let cipher = XChaCha20Poly1305::new(cipher_key);
    //   let ciphertext = cipher.encrypt(cipher_nonce, plaintext.as_bytes())?;
    //   hex::encode(ciphertext)
    let _ = (key, nonce);
    format!("stub:xchacha20:encrypted:{}", hex_stub(plaintext))
}

/// Decrypt ciphertext using XChaCha20-Poly1305 with a 256-bit key.
///
/// The nonce must match the one used during encryption.
/// Returns the decrypted plaintext as a UTF-8 string.
///
/// Real implementation: use the `chacha20poly1305` crate's `XChaCha20Poly1305`.
#[wasm_bindgen]
pub fn xchacha20poly1305_decrypt(ciphertext: &str, key: &str, nonce: &str) -> String {
    // TODO: Replace with real XChaCha20-Poly1305 decryption.
    //   use chacha20poly1305::{XChaCha20Poly1305, Key, XNonce, aead::Aead, KeyInit};
    //   let cipher_key = Key::from_slice(&hex::decode(key)?);
    //   let cipher_nonce = XNonce::from_slice(&hex::decode(nonce)?);
    //   let cipher = XChaCha20Poly1305::new(cipher_key);
    //   let plaintext = cipher.decrypt(cipher_nonce, hex::decode(ciphertext)?.as_ref())?;
    //   String::from_utf8(plaintext)?
    let _ = (key, nonce);
    format!("stub:xchacha20:decrypted:{}", hex_stub(ciphertext))
}

// =============================================================================
// HKDF-SHAKE512 — Key Derivation
// =============================================================================

/// Derive keying material using HKDF with SHAKE-512 as the underlying PRF.
///
/// Arguments:
///   - ikm: input keying material (hex-encoded)
///   - salt: optional salt (hex-encoded, can be empty string for no salt)
///   - info: context/application-specific info string
///
/// Returns 32 bytes of derived key material, hex-encoded.
///
/// Real implementation: use the `hkdf` crate with a SHAKE-512 hash.
#[wasm_bindgen]
pub fn hkdf_shake512_derive(ikm: &str, salt: &str, info: &str) -> String {
    // TODO: Replace with real HKDF-SHAKE512 derivation.
    //   use hkdf::Hkdf;
    //   use sha3::Sha3_512;  // or SHAKE-512 wrapper
    //   let salt_bytes = if salt.is_empty() { None } else { Some(hex::decode(salt)?) };
    //   let hk = Hkdf::<Sha3_512>::new(salt_bytes.as_deref(), &hex::decode(ikm)?);
    //   let mut okm = [0u8; 32];
    //   hk.expand(info.as_bytes(), &mut okm)?;
    //   hex::encode(okm)
    let _ = (salt, info);
    format!("stub:hkdf_shake512:{}", hex_stub(ikm))
}

// =============================================================================
// ChaCha20-DRBG — Random Number Generation
// =============================================================================

/// Generate pseudorandom bytes using a ChaCha20-based DRBG.
///
/// Arguments:
///   - seed: 256-bit seed, hex-encoded (64 hex characters)
///   - length: number of pseudorandom bytes to generate
///
/// Returns hex-encoded pseudorandom output.
///
/// Real implementation: use the `rand_chacha` crate's `ChaCha20Rng`
/// seeded from the provided seed bytes.
#[wasm_bindgen]
pub fn chacha20_drbg_generate(seed: &str, length: u32) -> String {
    // TODO: Replace with real ChaCha20-DRBG generation.
    //   use rand_chacha::ChaCha20Rng;
    //   use rand::SeedableRng;
    //   use rand::RngCore;
    //   let seed_bytes: [u8; 32] = hex::decode(seed)?[..32].try_into()?;
    //   let mut rng = ChaCha20Rng::from_seed(seed_bytes);
    //   let mut output = vec![0u8; length as usize];
    //   rng.fill_bytes(&mut output);
    //   hex::encode(output)
    let _ = seed;
    // Return a deterministic stub of the requested length
    "00".repeat(length as usize)
}

// =============================================================================
// User-Friendly Hash Name
// =============================================================================

/// Convert a hex-encoded hash digest to a human-readable name.
///
/// Maps pairs of hex bytes to words from a curated wordlist (based on
/// the EFF large wordlist), producing a sequence like
/// "correct-horse-battery-staple" that is easier for humans to recognise
/// and compare than raw hex.
///
/// Real implementation: embed the EFF wordlist and map byte pairs to
/// word indices.
#[wasm_bindgen]
pub fn user_friendly_hash_name(hash: &str) -> String {
    // TODO: Replace with real wordlist mapping.
    //   1. Decode hex hash to bytes
    //   2. Take first 8 bytes (4 word-pairs)
    //   3. Map each u16 (big-endian) to wordlist[index % wordlist.len()]
    //   4. Join with hyphens
    //   Example: "a1b2c3d4e5f6a7b8..." -> "correct-horse-battery-staple"
    let prefix = if hash.len() >= 10 {
        &hash[..10]
    } else {
        hash
    };
    format!("doc-{}", prefix)
}

// =============================================================================
// Internal Helpers (not exported to WASM)
// =============================================================================

/// Produce a short deterministic hex-like stub from an input string.
/// Used only by stub functions to create distinguishable placeholder output.
fn hex_stub(input: &str) -> String {
    // Simple non-cryptographic hash for stub differentiation.
    // This is NOT a real hash — it just makes stubs distinguishable.
    let mut hash: u64 = 0xcbf29ce484222325; // FNV-1a offset basis
    for byte in input.as_bytes() {
        hash ^= *byte as u64;
        hash = hash.wrapping_mul(0x100000001b3); // FNV-1a prime
    }
    format!("{:016x}", hash)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shake3_512_hash_returns_stub() {
        let result = shake3_512_hash("hello");
        assert!(result.starts_with("stub:shake3_512:"));
    }

    #[test]
    fn test_blake3_hash_returns_stub() {
        let result = blake3_hash("hello");
        assert!(result.starts_with("stub:blake3:"));
    }

    #[test]
    fn test_argon2id_hash_returns_stub() {
        let result = argon2id_hash("password", "salt123");
        assert!(result.starts_with("stub:argon2id:"));
    }

    #[test]
    fn test_dilithium5_verify_returns_false() {
        // Stub always returns false
        assert!(!dilithium5_verify("msg", "sig", "pk"));
    }

    #[test]
    fn test_chacha20_drbg_length() {
        let result = chacha20_drbg_generate("00".repeat(32).as_str(), 16);
        // 16 bytes = 32 hex characters
        assert_eq!(result.len(), 32);
    }

    #[test]
    fn test_user_friendly_hash_name_short() {
        let result = user_friendly_hash_name("abcdef0123");
        assert_eq!(result, "doc-abcdef0123");
    }

    #[test]
    fn test_user_friendly_hash_name_long() {
        let result = user_friendly_hash_name("abcdef0123456789abcdef");
        assert_eq!(result, "doc-abcdef0123");
    }

    #[test]
    fn test_hex_stub_deterministic() {
        let a = hex_stub("test");
        let b = hex_stub("test");
        assert_eq!(a, b);
    }

    #[test]
    fn test_hex_stub_different_inputs() {
        let a = hex_stub("hello");
        let b = hex_stub("world");
        assert_ne!(a, b);
    }
}
