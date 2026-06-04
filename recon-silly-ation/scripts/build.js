// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
// Build script for ReScript compilation

console.log("Building ReScript code...");

// Check if rescript is available
try {
  const rescriptCheck = await Deno.run({
    cmd: ["npm", "run", "build"],
    stdout: "inherit",
    stderr: "inherit",
  }).status();

  if (rescriptCheck.success) {
    console.log("✅ ReScript build successful");
  } else {
    console.error("❌ ReScript build failed");
    Deno.exit(1);
  }
} catch (error) {
  console.error("❌ Error running ReScript build:", error);
  Deno.exit(1);
}
