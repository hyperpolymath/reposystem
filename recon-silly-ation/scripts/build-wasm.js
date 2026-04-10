// Build script for WASM modules
// Compiles Rust to WebAssembly

console.log("Building WASM modules...");

// Check if Rust is available
const rustCheck = await Deno.run({
  cmd: ["rustc", "--version"],
  stdout: "piped",
  stderr: "piped",
}).status();

if (!rustCheck.success) {
  console.error("❌ Rust not found. Install Rust to build WASM modules:");
  console.error("   curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh");
  Deno.exit(1);
}

// Add wasm32 target
console.log("Adding wasm32-unknown-unknown target...");
await Deno.run({
  cmd: ["rustup", "target", "add", "wasm32-unknown-unknown"],
}).status();

// Build Rust to WASM
console.log("Compiling Rust to WebAssembly...");
const build = Deno.run({
  cmd: [
    "cargo",
    "build",
    "--release",
    "--target",
    "wasm32-unknown-unknown",
    "--manifest-path",
    "wasm-modules/Cargo.toml",
  ],
  stdout: "inherit",
  stderr: "inherit",
});

const status = await build.status();

if (status.success) {
  // Copy WASM file to src/wasm/
  console.log("Copying WASM binary...");
  await Deno.copyFile(
    "wasm-modules/target/wasm32-unknown-unknown/release/recon_wasm.wasm",
    "src/wasm/hasher.wasm",
  );
  console.log("✅ WASM modules built successfully");
} else {
  console.error("❌ WASM build failed");
  Deno.exit(1);
}
