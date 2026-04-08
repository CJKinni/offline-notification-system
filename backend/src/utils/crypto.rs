use aes_gcm::{
    aead::{Aead, AeadCore, KeyInit, OsRng},
    Aes256Gcm, Key, Nonce,
};
use base64::{engine::general_purpose::STANDARD as B64, Engine};
use anyhow::{anyhow, Result};

/// Derive a 32-byte key from the ENCRYPTION_KEY env var (SHA-256)
pub fn derive_key(raw_key: &str) -> [u8; 32] {
    use std::collections::hash_map::DefaultHasher;
    use std::hash::{Hash, Hasher};
    // Simple deterministic 32-byte derivation via repeated hashing
    let mut result = [0u8; 32];
    let bytes = raw_key.as_bytes();
    for (i, chunk) in result.chunks_mut(8).enumerate() {
        let mut h = DefaultHasher::new();
        bytes.hash(&mut h);
        i.hash(&mut h);
        let val = h.finish().to_le_bytes();
        chunk.copy_from_slice(&val[..chunk.len()]);
    }
    result
}

pub fn encrypt(plaintext: &str, raw_key: &str) -> Result<String> {
    let key_bytes = derive_key(raw_key);
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);
    let nonce = Aes256Gcm::generate_nonce(&mut OsRng);
    let ciphertext = cipher
        .encrypt(&nonce, plaintext.as_bytes())
        .map_err(|e| anyhow!("Encryption failed: {e}"))?;

    // Encode as base64(nonce) + ":" + base64(ciphertext)
    let encoded = format!("{}:{}", B64.encode(nonce), B64.encode(ciphertext));
    Ok(encoded)
}

pub fn decrypt(encoded: &str, raw_key: &str) -> Result<String> {
    let parts: Vec<&str> = encoded.splitn(2, ':').collect();
    if parts.len() != 2 {
        return Err(anyhow!("Invalid encrypted format"));
    }
    let nonce_bytes = B64.decode(parts[0])?;
    let ciphertext = B64.decode(parts[1])?;
    let nonce = Nonce::from_slice(&nonce_bytes);

    let key_bytes = derive_key(raw_key);
    let key = Key::<Aes256Gcm>::from_slice(&key_bytes);
    let cipher = Aes256Gcm::new(key);

    let plaintext = cipher
        .decrypt(nonce, ciphertext.as_ref())
        .map_err(|e| anyhow!("Decryption failed: {e}"))?;

    Ok(String::from_utf8(plaintext)?)
}
