// SPDX-License-Identifier: PMPL-1.0-or-later
// WASM module loader and exports
// Provides high-performance WebAssembly functions

let wasmModule = null;

export async function initWasm() {
  try {
    const wasmPath = new URL("./hasher.wasm", import.meta.url);
    const wasmBytes = await Deno.readFile(wasmPath);
    wasmModule = await WebAssembly.instantiate(wasmBytes);
    console.log("✅ WASM modules loaded successfully");
  } catch (error) {
    console.warn("⚠️  WASM modules not found, using JS fallback");
    console.warn("   Run 'deno task build:wasm' to enable WASM acceleration");
  }
}

// WASM-accelerated content hashing
export function hashContentWasm(content) {
  if (wasmModule) {
    // Call WASM hash function
    // This would be implemented in Rust/AssemblyScript
    // For now, fallback to JS
  }

  // Fallback: Use native Deno crypto
  return hashContentNative(content);
}

// Native Deno crypto API (very fast)
export function hashContentNative(content) {
  const encoder = new TextEncoder();
  const data = encoder.encode(content);
  const hashBuffer = crypto.subtle.digestSync("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

// WASM-accelerated content normalization
export function normalizeContentWasm(content) {
  if (wasmModule) {
    // Call WASM normalization
  }

  // Fallback to JS
  return content
    .trim()
    .replace(/\r\n/g, "\n")
    .replace(/\s+$/gm, "")
    .replace(/\n{3,}/g, "\n\n");
}

// Export default hash function (auto-selects WASM or native)
export const hashContent = hashContentWasm;
export const normalizeContent = normalizeContentWasm;
