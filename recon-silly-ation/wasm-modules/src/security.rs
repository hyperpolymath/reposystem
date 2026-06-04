// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// security.rs - Post-quantum cryptographic primitives for recon-silly-ation
//
// This module provides WASM-exported cryptographic operations.  Every
// function is now backed by a real, well-known audited (or community-
// reviewed pure-Rust) implementation from the RustCrypto ecosystem.
//
// SECURITY NOTE: This is a security-sensitive module.  No primitive is
// hand-rolled.  The crates used are:
//   - sha3                (SHA-3 / SHAKE256 XOF, SHA3-512)
//   - blake3              (BLAKE3)
//   - argon2              (Argon2id, PHC string output)
//   - ml-dsa              (ML-DSA-87 / "Dilithium5", FIPS 204, pure Rust)
//   - ml-kem              (ML-KEM-1024 / "Kyber1024", FIPS 203, pure Rust)
//   - chacha20poly1305    (XChaCha20-Poly1305 AEAD)
//   - hkdf + sha3         (HKDF-Expand/Extract over SHA3-512)
//   - rand_chacha         (ChaCha20-based DRBG)
//
// The pure-Rust `ml-dsa` / `ml-kem` crates are used instead of the
// C-backed `pqcrypto-*` crates specifically because this crate is a
// `cdylib` targeting `wasm32-unknown-unknown`, where linking PQClean C
// code is not viable.  Both crates are `#![no_std]` and wasm-friendly.
//
// Public function signatures are unchanged; only internals were swapped
// from placeholder stubs to real implementations.

use wasm_bindgen::prelude::*;

use argon2::{
    password_hash::{PasswordHasher, SaltString},
    Algorithm, Argon2, Params, Version,
};
use chacha20poly1305::{
    aead::{Aead, KeyInit},
    Key, XChaCha20Poly1305, XNonce,
};
use hkdf::Hkdf;
use ml_dsa::{
    signature::{Signer, Verifier},
    EncodedSignature, EncodedSigningKey, EncodedVerifyingKey, KeyGen, MlDsa87, Signature,
    SigningKey, VerifyingKey,
};
use ml_kem::{
    kem::{Decapsulate, Encapsulate},
    Encoded, EncodedSizeUser, KemCore, MlKem1024,
};
use rand_chacha::ChaCha20Rng;
use rand_core::SeedableRng;
use sha3::{
    digest::{ExtendableOutput, Update, XofReader},
    Sha3_512, Shake256,
};

// =============================================================================
// CSPRNG helper
// =============================================================================

/// A cryptographically secure RNG seeded from the platform entropy source.
///
/// On `wasm32-unknown-unknown` this resolves through `getrandom` (the
/// consumer must enable the `getrandom/js` feature, which is wired in
/// `Cargo.toml` via a target-gated dependency).  On native targets it
/// uses the OS CSPRNG directly.  We expand the 32-byte OS seed with
/// ChaCha20 so all downstream key generation draws from a single
/// well-defined CSPRNG.
fn secure_rng() -> Result<ChaCha20Rng, String> {
    let mut seed = [0u8; 32];
    getrandom::getrandom(&mut seed).map_err(|e| format!("entropy source unavailable: {e}"))?;
    Ok(ChaCha20Rng::from_seed(seed))
}

// =============================================================================
// Hash Functions
// =============================================================================

/// Compute a SHAKE-512 (SHA-3 / Keccak XOF) digest of the input.
///
/// "SHAKE3-512" denotes the SHA-3-family extendable-output function with
/// 512 bits (64 bytes) of squeezed output.  Implemented with the `sha3`
/// crate's `Shake256` XOF.
#[wasm_bindgen]
pub fn shake3_512_hash(input: &str) -> String {
    let mut hasher = Shake256::default();
    hasher.update(input.as_bytes());
    let mut reader = hasher.finalize_xof();
    let mut output = [0u8; 64];
    reader.read(&mut output);
    hex::encode(output)
}

/// Compute a BLAKE3 digest of the input (256-bit, hex-encoded).
#[wasm_bindgen]
pub fn blake3_hash(input: &str) -> String {
    let hash = blake3::hash(input.as_bytes());
    hash.to_hex().to_string()
}

/// Compute an Argon2id hash of the input with the given salt.
///
/// Argon2id, memory cost 64 MiB, time cost 3, parallelism 4, 32-byte
/// output.  Returns the PHC-format string (`$argon2id$v=19$...`).  The
/// `salt` argument is used as the salt material (base64-encoded per the
/// PHC `SaltString` format).
#[wasm_bindgen]
pub fn argon2id_hash(input: &str, salt: &str) -> String {
    let params = match Params::new(65536, 3, 4, Some(32)) {
        Ok(p) => p,
        Err(e) => return format!("error:argon2id:params:{e}"),
    };
    let argon2 = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let salt_obj = match SaltString::from_b64(salt) {
        Ok(s) => s,
        Err(e) => return format!("error:argon2id:salt:{e}"),
    };
    match argon2.hash_password(input.as_bytes(), &salt_obj) {
        Ok(h) => h.to_string(),
        Err(e) => format!("error:argon2id:hash:{e}"),
    }
}

// =============================================================================
// ML-DSA-87 (FIPS 204, "Dilithium5") — Digital Signatures
// =============================================================================

/// Generate an ML-DSA-87 (Dilithium5-class) key pair.
///
/// Returns JSON: `{ "public_key": "<hex>", "private_key": "<hex>" }`.
/// Keys are encoded with the FIPS 204 fixed-size encodings.
#[wasm_bindgen]
pub fn dilithium5_keygen() -> JsValue {
    JsValue::from_str(&dilithium5_keygen_impl())
}

/// Pure-Rust core for [`dilithium5_keygen`]; returns the JSON string.
/// Kept separate so it is unit-testable on native targets without the
/// wasm-bindgen runtime.
fn dilithium5_keygen_impl() -> String {
    let mut rng = match secure_rng() {
        Ok(r) => r,
        Err(e) => return format!("{{\"error\":\"{e}\"}}"),
    };
    let kp = MlDsa87::key_gen(&mut rng);
    let pk = kp.verifying_key().encode();
    let sk = kp.signing_key().encode();
    serde_json::json!({
        "public_key": hex::encode(pk.as_slice()),
        "private_key": hex::encode(sk.as_slice()),
    })
    .to_string()
}

/// Sign a message using ML-DSA-87 (deterministic variant, empty context).
///
/// Returns the hex-encoded fixed-size signature.
#[wasm_bindgen]
pub fn dilithium5_sign(message: &str, private_key: &str) -> String {
    let sk_bytes = match hex::decode(private_key) {
        Ok(b) => b,
        Err(e) => return format!("error:dilithium5_sign:hex:{e}"),
    };
    let enc = match EncodedSigningKey::<MlDsa87>::try_from(sk_bytes.as_slice()) {
        Ok(e) => e,
        Err(_) => return "error:dilithium5_sign:bad_private_key_length".to_string(),
    };
    let sk = SigningKey::<MlDsa87>::decode(&enc);
    let sig = sk.sign(message.as_bytes());
    hex::encode(sig.encode().as_slice())
}

/// Verify an ML-DSA-87 signature.  Returns true iff valid.
#[wasm_bindgen]
pub fn dilithium5_verify(message: &str, signature: &str, public_key: &str) -> bool {
    let pk_bytes = match hex::decode(public_key) {
        Ok(b) => b,
        Err(_) => return false,
    };
    let sig_bytes = match hex::decode(signature) {
        Ok(b) => b,
        Err(_) => return false,
    };
    let pk_enc = match EncodedVerifyingKey::<MlDsa87>::try_from(pk_bytes.as_slice()) {
        Ok(e) => e,
        Err(_) => return false,
    };
    let sig_enc = match EncodedSignature::<MlDsa87>::try_from(sig_bytes.as_slice()) {
        Ok(e) => e,
        Err(_) => return false,
    };
    let sig = match Signature::<MlDsa87>::decode(&sig_enc) {
        Some(s) => s,
        None => return false,
    };
    let vk = VerifyingKey::<MlDsa87>::decode(&pk_enc);
    vk.verify(message.as_bytes(), &sig).is_ok()
}

// =============================================================================
// ML-KEM-1024 (FIPS 203, "Kyber1024") — Key Encapsulation
// =============================================================================

/// Generate an ML-KEM-1024 (Kyber1024-class) key pair.
///
/// Returns JSON: `{ "public_key": "<hex>", "private_key": "<hex>" }`
/// where `public_key` is the encapsulation key and `private_key` is the
/// decapsulation key, FIPS 203 fixed-size encodings.
#[wasm_bindgen]
pub fn kyber1024_keygen() -> JsValue {
    JsValue::from_str(&kyber1024_keygen_impl())
}

/// Pure-Rust core for [`kyber1024_keygen`]; returns the JSON string.
fn kyber1024_keygen_impl() -> String {
    let mut rng = match secure_rng() {
        Ok(r) => r,
        Err(e) => return format!("{{\"error\":\"{e}\"}}"),
    };
    let (dk, ek) = MlKem1024::generate(&mut rng);
    serde_json::json!({
        "public_key": hex::encode(ek.as_bytes().as_slice()),
        "private_key": hex::encode(dk.as_bytes().as_slice()),
    })
    .to_string()
}

/// Encapsulate a shared secret to an ML-KEM-1024 public (encapsulation)
/// key.
///
/// Returns JSON: `{ "ciphertext": "<hex>", "shared_secret": "<hex>" }`.
#[wasm_bindgen]
pub fn kyber1024_encapsulate(public_key: &str) -> JsValue {
    JsValue::from_str(&kyber1024_encapsulate_impl(public_key))
}

/// Pure-Rust core for [`kyber1024_encapsulate`]; returns the JSON string.
fn kyber1024_encapsulate_impl(public_key: &str) -> String {
    let err = |m: &str| format!("{{\"error\":\"{m}\"}}");
    let ek_bytes = match hex::decode(public_key) {
        Ok(b) => b,
        Err(e) => return err(&format!("hex:{e}")),
    };
    let ek_enc =
        match Encoded::<<MlKem1024 as KemCore>::EncapsulationKey>::try_from(ek_bytes.as_slice()) {
            Ok(e) => e,
            Err(_) => return err("bad_public_key_length"),
        };
    let ek = <MlKem1024 as KemCore>::EncapsulationKey::from_bytes(&ek_enc);
    let mut rng = match secure_rng() {
        Ok(r) => r,
        Err(e) => return err(&e),
    };
    let (ct, ss) = match ek.encapsulate(&mut rng) {
        Ok(v) => v,
        Err(_) => return err("encapsulation_failed"),
    };
    serde_json::json!({
        "ciphertext": hex::encode(ct.as_slice()),
        "shared_secret": hex::encode(ss.as_slice()),
    })
    .to_string()
}

/// Decapsulate a shared secret from an ML-KEM-1024 ciphertext using the
/// private (decapsulation) key.  Returns the hex-encoded 32-byte shared
/// secret.
#[wasm_bindgen]
pub fn kyber1024_decapsulate(ciphertext: &str, private_key: &str) -> String {
    let dk_bytes = match hex::decode(private_key) {
        Ok(b) => b,
        Err(e) => return format!("error:kyber1024_decapsulate:hex_sk:{e}"),
    };
    let ct_bytes = match hex::decode(ciphertext) {
        Ok(b) => b,
        Err(e) => return format!("error:kyber1024_decapsulate:hex_ct:{e}"),
    };
    let dk_enc =
        match Encoded::<<MlKem1024 as KemCore>::DecapsulationKey>::try_from(dk_bytes.as_slice()) {
            Ok(e) => e,
            Err(_) => return "error:kyber1024_decapsulate:bad_private_key_length".to_string(),
        };
    let ct = match ml_kem::Ciphertext::<MlKem1024>::try_from(ct_bytes.as_slice()) {
        Ok(c) => c,
        Err(_) => return "error:kyber1024_decapsulate:bad_ciphertext_length".to_string(),
    };
    let dk = <MlKem1024 as KemCore>::DecapsulationKey::from_bytes(&dk_enc);
    match dk.decapsulate(&ct) {
        Ok(ss) => hex::encode(ss.as_slice()),
        Err(_) => "error:kyber1024_decapsulate:decapsulation_failed".to_string(),
    }
}

// =============================================================================
// XChaCha20-Poly1305-256 — Symmetric AEAD
// =============================================================================

/// Encrypt plaintext using XChaCha20-Poly1305 with a 256-bit key.
///
/// `key` is 32 bytes hex-encoded, `nonce` is 24 bytes hex-encoded.
/// Returns hex-encoded ciphertext with the 16-byte Poly1305 tag
/// appended.
#[wasm_bindgen]
pub fn xchacha20poly1305_encrypt(plaintext: &str, key: &str, nonce: &str) -> String {
    let key_bytes = match hex::decode(key) {
        Ok(b) => b,
        Err(e) => return format!("error:xchacha20_encrypt:hex_key:{e}"),
    };
    let nonce_bytes = match hex::decode(nonce) {
        Ok(b) => b,
        Err(e) => return format!("error:xchacha20_encrypt:hex_nonce:{e}"),
    };
    if key_bytes.len() != 32 {
        return "error:xchacha20_encrypt:key_must_be_32_bytes".to_string();
    }
    if nonce_bytes.len() != 24 {
        return "error:xchacha20_encrypt:nonce_must_be_24_bytes".to_string();
    }
    let cipher = XChaCha20Poly1305::new(Key::from_slice(&key_bytes));
    match cipher.encrypt(XNonce::from_slice(&nonce_bytes), plaintext.as_bytes()) {
        Ok(ct) => hex::encode(ct),
        Err(_) => "error:xchacha20_encrypt:aead_failure".to_string(),
    }
}

/// Decrypt ciphertext using XChaCha20-Poly1305 with a 256-bit key.
/// Returns the decrypted plaintext as a UTF-8 string.
#[wasm_bindgen]
pub fn xchacha20poly1305_decrypt(ciphertext: &str, key: &str, nonce: &str) -> String {
    let key_bytes = match hex::decode(key) {
        Ok(b) => b,
        Err(e) => return format!("error:xchacha20_decrypt:hex_key:{e}"),
    };
    let nonce_bytes = match hex::decode(nonce) {
        Ok(b) => b,
        Err(e) => return format!("error:xchacha20_decrypt:hex_nonce:{e}"),
    };
    let ct_bytes = match hex::decode(ciphertext) {
        Ok(b) => b,
        Err(e) => return format!("error:xchacha20_decrypt:hex_ct:{e}"),
    };
    if key_bytes.len() != 32 {
        return "error:xchacha20_decrypt:key_must_be_32_bytes".to_string();
    }
    if nonce_bytes.len() != 24 {
        return "error:xchacha20_decrypt:nonce_must_be_24_bytes".to_string();
    }
    let cipher = XChaCha20Poly1305::new(Key::from_slice(&key_bytes));
    match cipher.decrypt(XNonce::from_slice(&nonce_bytes), ct_bytes.as_ref()) {
        Ok(pt) => match String::from_utf8(pt) {
            Ok(s) => s,
            Err(_) => "error:xchacha20_decrypt:plaintext_not_utf8".to_string(),
        },
        Err(_) => "error:xchacha20_decrypt:authentication_failed".to_string(),
    }
}

// =============================================================================
// HKDF-SHA3-512 — Key Derivation
// =============================================================================

/// Derive 32 bytes of keying material using HKDF with SHA3-512 as the
/// underlying hash.
///
/// Arguments:
///   - `ikm`: input keying material (hex-encoded)
///   - `salt`: optional salt (hex-encoded, empty string = no salt)
///   - `info`: context/application-specific info string
///
/// Returns 32 bytes of derived key material, hex-encoded.
#[wasm_bindgen]
pub fn hkdf_shake512_derive(ikm: &str, salt: &str, info: &str) -> String {
    let ikm_bytes = match hex::decode(ikm) {
        Ok(b) => b,
        Err(e) => return format!("error:hkdf:hex_ikm:{e}"),
    };
    let salt_bytes = if salt.is_empty() {
        None
    } else {
        match hex::decode(salt) {
            Ok(b) => Some(b),
            Err(e) => return format!("error:hkdf:hex_salt:{e}"),
        }
    };
    let hk = Hkdf::<Sha3_512>::new(salt_bytes.as_deref(), &ikm_bytes);
    let mut okm = [0u8; 32];
    match hk.expand(info.as_bytes(), &mut okm) {
        Ok(()) => hex::encode(okm),
        Err(_) => "error:hkdf:expand_failed".to_string(),
    }
}

// =============================================================================
// ChaCha20-DRBG — Deterministic Random Byte Generation
// =============================================================================

/// Generate pseudorandom bytes using a ChaCha20-based DRBG seeded from
/// the provided 256-bit seed.
///
/// Arguments:
///   - `seed`: 256-bit seed, hex-encoded (64 hex characters)
///   - `length`: number of pseudorandom bytes to generate
///
/// Returns hex-encoded pseudorandom output.
#[wasm_bindgen]
pub fn chacha20_drbg_generate(seed: &str, length: u32) -> String {
    use rand_core::RngCore;
    let seed_bytes = match hex::decode(seed) {
        Ok(b) => b,
        Err(e) => return format!("error:chacha20_drbg:hex_seed:{e}"),
    };
    let seed_arr: [u8; 32] = match seed_bytes.as_slice().try_into() {
        Ok(a) => a,
        Err(_) => return "error:chacha20_drbg:seed_must_be_32_bytes".to_string(),
    };
    let mut rng = ChaCha20Rng::from_seed(seed_arr);
    let mut output = vec![0u8; length as usize];
    rng.fill_bytes(&mut output);
    hex::encode(output)
}

// =============================================================================
// User-Friendly Hash Name
// =============================================================================

/// A small curated wordlist (subset of the EFF large wordlist) used to
/// render a hash digest as a memorable hyphen-joined phrase.  256 words
/// so each byte maps directly to one word.
const WORDLIST: [&str; 256] = [
    "abandon", "ability", "able", "about", "above", "absent", "absorb", "abstract", "absurd",
    "abuse", "access", "accident", "account", "accuse", "achieve", "acid", "acoustic", "acquire",
    "across", "action", "actor", "actual", "adapt", "addict", "address", "adjust", "admit",
    "adult", "advance", "advice", "aerobic", "affair", "afford", "afraid", "again", "agent",
    "agree", "ahead", "aim", "air", "airport", "aisle", "alarm", "album", "alcohol", "alert",
    "alien", "alley", "allow", "almost", "alone", "alpha", "already", "also", "alter", "always",
    "amateur", "amazing", "among", "amount", "amused", "anchor", "ancient", "anger", "angle",
    "angry", "animal", "ankle", "announce", "annual", "another", "answer", "antenna", "antique",
    "anxiety", "any", "apart", "apology", "appear", "apple", "approve", "april", "arch", "arctic",
    "area", "arena", "argue", "arm", "armed", "armor", "army", "around", "arrange", "arrest",
    "arrive", "arrow", "art", "artist", "artwork", "ask", "aspect", "assault", "asset", "assist",
    "assume", "asthma", "athlete", "atom", "attack", "attend", "attitude", "attract", "auction",
    "audit", "august", "aunt", "author", "auto", "autumn", "average", "avocado", "avoid", "awake",
    "aware", "away", "awesome", "awful", "awkward", "axis", "baby", "bachelor", "bacon", "badge",
    "bag", "balance", "balcony", "ball", "bamboo", "banana", "banner", "bar", "barely", "bargain",
    "barrel", "base", "basic", "basket", "battle", "beach", "bean", "beauty", "because", "become",
    "beef", "before", "begin", "behave", "behind", "believe", "below", "belt", "bench", "benefit",
    "best", "betray", "better", "between", "beyond", "bicycle", "bid", "bike", "bind", "biology",
    "bird", "birth", "bitter", "black", "blade", "blame", "blanket", "blast", "bleak", "bless",
    "blind", "blood", "blossom", "blouse", "blue", "blur", "blush", "board", "boat", "body",
    "boil", "bomb", "bone", "bonus", "book", "boost", "border", "boring", "borrow", "boss",
    "bottom", "bounce", "box", "boy", "bracket", "brain", "brand", "brass", "brave", "bread",
    "breeze", "brick", "bridge", "brief", "bright", "bring", "brisk", "broccoli", "broken",
    "bronze", "broom", "brother", "brown", "brush", "bubble", "buddy", "budget", "buffalo",
    "build", "bulb", "bulk", "bullet", "bundle", "bunker", "burden", "burger", "burst", "bus",
    "business", "busy", "butter", "buyer", "buzz", "cabbage", "cabin", "cable", "cactus", "cage",
    "cake", "call", "calm", "camera", "camp",
];

/// Convert a hex-encoded hash digest to a human-readable phrase.
///
/// Decodes the hex digest and maps the first four bytes to four words
/// from a curated 256-word list, producing a phrase like
/// "correct-horse-battery-staple".  If the hash cannot be hex-decoded
/// the input is hashed with BLAKE3 first so a phrase is always
/// produced.
#[wasm_bindgen]
pub fn user_friendly_hash_name(hash: &str) -> String {
    let bytes = match hex::decode(hash) {
        Ok(b) if b.len() >= 4 => b,
        _ => blake3::hash(hash.as_bytes()).as_bytes().to_vec(),
    };
    let words: Vec<&str> = bytes
        .iter()
        .take(4)
        .map(|b| WORDLIST[*b as usize])
        .collect();
    words.join("-")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_shake3_512_hash_known_vector() {
        // SHAKE256 of the empty string, first 64 bytes (NIST test vector).
        let result = shake3_512_hash("");
        assert_eq!(
            result,
            "46b9dd2b0ba88d13233b3feb743eeb243fcd52ea62b81b82b50c27646ed5762f\
             d75dc4ddd8c0f200cb05019d67b592f6fc821c49479ab48640292eacb3b7c4be"
        );
    }

    #[test]
    fn test_blake3_hash_known_vector() {
        // BLAKE3 of the empty string.
        let result = blake3_hash("");
        assert_eq!(
            result,
            "af1349b9f5f9a1a6a0404dea36dcc9499bcb25c9adc112b7cc9a93cae41f3262"
        );
    }

    #[test]
    fn test_argon2id_hash_phc_format() {
        let salt = "c29tZXNhbHR2YWx1ZQ"; // base64 "somesaltvalue"
        let result = argon2id_hash("password", salt);
        assert!(
            result.starts_with("$argon2id$v=19$"),
            "got: {result}"
        );
    }

    #[test]
    fn test_dilithium5_sign_verify_round_trip() {
        let kp_json = dilithium5_keygen_impl();
        let kp: serde_json::Value = serde_json::from_str(&kp_json).unwrap();
        let pk = kp["public_key"].as_str().unwrap();
        let sk = kp["private_key"].as_str().unwrap();
        let sig = dilithium5_sign("attestation message", sk);
        assert!(!sig.starts_with("error:"), "sign error: {sig}");
        assert!(dilithium5_verify("attestation message", &sig, pk));
        assert!(!dilithium5_verify("tampered message", &sig, pk));
    }

    #[test]
    fn test_kyber1024_encap_decap_round_trip() {
        let kp_json = kyber1024_keygen_impl();
        let kp: serde_json::Value = serde_json::from_str(&kp_json).unwrap();
        let pk = kp["public_key"].as_str().unwrap();
        let sk = kp["private_key"].as_str().unwrap();
        let enc_json = kyber1024_encapsulate_impl(pk);
        let enc: serde_json::Value = serde_json::from_str(&enc_json).unwrap();
        let ct = enc["ciphertext"].as_str().unwrap();
        let ss_sender = enc["shared_secret"].as_str().unwrap();
        let ss_receiver = kyber1024_decapsulate(ct, sk);
        assert_eq!(ss_sender, ss_receiver);
    }

    #[test]
    fn test_xchacha20poly1305_round_trip() {
        let key = "00".repeat(32);
        let nonce = "00".repeat(24);
        let ct = xchacha20poly1305_encrypt("hello world", &key, &nonce);
        assert!(!ct.starts_with("error:"), "encrypt error: {ct}");
        let pt = xchacha20poly1305_decrypt(&ct, &key, &nonce);
        assert_eq!(pt, "hello world");
    }

    #[test]
    fn test_xchacha20poly1305_tamper_detected() {
        let key = "11".repeat(32);
        let nonce = "22".repeat(24);
        let mut ct = xchacha20poly1305_encrypt("secret", &key, &nonce);
        // Flip the last hex nibble to corrupt the tag.
        let last = ct.pop().unwrap();
        ct.push(if last == '0' { '1' } else { '0' });
        let pt = xchacha20poly1305_decrypt(&ct, &key, &nonce);
        assert!(pt.starts_with("error:"), "tamper not detected: {pt}");
    }

    #[test]
    fn test_hkdf_shake512_deterministic() {
        let a = hkdf_shake512_derive("00112233", "aabb", "context");
        let b = hkdf_shake512_derive("00112233", "aabb", "context");
        assert_eq!(a, b);
        assert_eq!(a.len(), 64); // 32 bytes hex
        let c = hkdf_shake512_derive("00112233", "aabb", "different");
        assert_ne!(a, c);
    }

    #[test]
    fn test_chacha20_drbg_deterministic_and_length() {
        let seed = "00".repeat(32);
        let a = chacha20_drbg_generate(&seed, 16);
        let b = chacha20_drbg_generate(&seed, 16);
        assert_eq!(a, b);
        assert_eq!(a.len(), 32); // 16 bytes hex
        // ChaCha20 keystream of an all-zero key/nonce is a known value;
        // assert it is not trivially all zeros.
        assert_ne!(a, "00".repeat(16));
    }

    #[test]
    fn test_user_friendly_hash_name_is_words() {
        let result = user_friendly_hash_name("00010203");
        assert_eq!(result, "abandon-ability-able-about");
    }

    #[test]
    fn test_user_friendly_hash_name_non_hex_fallback() {
        let result = user_friendly_hash_name("not-hex!");
        // Deterministic phrase from BLAKE3 of the input.
        assert_eq!(result.split('-').count(), 4);
    }
}
