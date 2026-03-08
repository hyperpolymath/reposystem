// src/manifest.rs
#[cfg(feature = "nickel")]
pub fn parse_nickel_manifest(path: &str) -> Result<MustFile, String> {
    use nickel_lang::eval::eval_file;
    let value = eval_file(path).map_err(|e| format!("Nickel error: {}", e))?;
    serde_json::from_value(value.into()).map_err(|e| e.to_string())
}
