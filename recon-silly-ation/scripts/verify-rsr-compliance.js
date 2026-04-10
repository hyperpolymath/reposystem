#!/usr/bin/env -S deno run --allow-read

// RSR (Rhodium Standard Repository) Compliance Verification Script
// Checks project against RSR framework standards

const GREEN = "\x1b[32m";
const RED = "\x1b[31m";
const YELLOW = "\x1b[33m";
const RESET = "\x1b[0m";
const BOLD = "\x1b[1m";

async function fileExists(path) {
  try {
    await Deno.stat(path);
    return true;
  } catch {
    return false;
  }
}

async function fileContains(path, content) {
  try {
    const text = await Deno.readTextFile(path);
    return text.includes(content);
  } catch {
    return false;
  }
}

const complianceChecks = [
  {
    category: "1. Documentation",
    checks: [
      {
        name: "README exists (AsciiDoc preferred)",
        required: true,
        check: async () =>
          await fileExists("README.adoc") || await fileExists("README.md"),
        points: 2,
      },
      {
        name: "LICENSE exists",
        required: true,
        check: () => fileExists("LICENSE"),
        points: 2,
      },
      {
        name: "SECURITY.md exists",
        required: true,
        check: () => fileExists("SECURITY.md"),
        points: 1,
      },
      {
        name: "CONTRIBUTING exists",
        required: true,
        check: async () =>
          await fileExists("CONTRIBUTING.adoc") ||
          await fileExists("CONTRIBUTING.md"),
        points: 2,
      },
      {
        name: "CODE_OF_CONDUCT.md exists",
        required: true,
        check: () => fileExists("CODE_OF_CONDUCT.md"),
        points: 1,
      },
      {
        name: "MAINTAINERS.md exists",
        required: false,
        check: () => fileExists("MAINTAINERS.md"),
        points: 1,
      },
      {
        name: "CHANGELOG exists",
        required: false,
        check: async () =>
          await fileExists("CHANGELOG.adoc") ||
          await fileExists("CHANGELOG.md"),
        points: 1,
      },
    ],
  },
  {
    category: "2. Security",
    checks: [
      {
        name: ".well-known/security.txt (RFC 9116)",
        required: true,
        check: () => fileExists(".well-known/security.txt"),
        points: 2,
      },
      {
        name: "security.txt has Contact field",
        required: true,
        check: () => fileContains(".well-known/security.txt", "Contact:"),
        points: 1,
      },
      {
        name: "security.txt has Expires field",
        required: true,
        check: () => fileContains(".well-known/security.txt", "Expires:"),
        points: 1,
      },
      {
        name: ".gitignore exists",
        required: true,
        check: () => fileExists(".gitignore"),
        points: 1,
      },
      {
        name: "SECURITY.md has vulnerability reporting",
        required: true,
        check: () => fileContains("SECURITY.md", "report"),
        points: 1,
      },
    ],
  },
  {
    category: "3. Licensing",
    checks: [
      {
        name: "LICENSE exists",
        required: true,
        check: () => fileExists("LICENSE"),
        points: 2,
      },
      {
        name: "PMPL-1.0-or-later (Palimpsest) license",
        required: false,
        check: () => fileContains("LICENSE", "Palimpsest"),
        points: 3,
      },
      {
        name: "Copyright year present",
        required: true,
        check: () => fileContains("LICENSE", "2025"),
        points: 1,
      },
    ],
  },
  {
    category: "4. Build Reproducibility",
    checks: [
      {
        name: "Build system (justfile/Makefile/etc.)",
        required: true,
        check: async () =>
          await fileExists("justfile") ||
          await fileExists("Makefile") ||
          await fileExists("build.sh"),
        points: 2,
      },
      {
        name: "Nix flake.nix",
        required: false,
        check: () => fileExists("flake.nix"),
        points: 2,
      },
      {
        name: "Container build (Containerfile/Dockerfile)",
        required: false,
        check: async () =>
          await fileExists("Containerfile") ||
          await fileExists("Dockerfile"),
        points: 2,
      },
      {
        name: "Compose file (podman-compose/docker-compose)",
        required: false,
        check: async () =>
          await fileExists("podman-compose.yml") ||
          await fileExists("docker-compose.yml"),
        points: 1,
      },
    ],
  },
  {
    category: "5. Testing",
    checks: [
      {
        name: "Tests directory exists",
        required: true,
        check: async () => {
          try {
            const stat = await Deno.stat("tests");
            return stat.isDirectory;
          } catch {
            return false;
          }
        },
        points: 2,
      },
      {
        name: "CI/CD configuration",
        required: true,
        check: async () =>
          await fileExists(".github/workflows/ci.yml") ||
          await fileExists(".gitlab-ci.yml"),
        points: 2,
      },
    ],
  },
  {
    category: "6. Community Governance",
    checks: [
      {
        name: "CODE_OF_CONDUCT.md",
        required: true,
        check: () => fileExists("CODE_OF_CONDUCT.md"),
        points: 2,
      },
      {
        name: "TPCF documentation",
        required: false,
        check: () => fileExists("docs/TPCF.adoc"),
        points: 2,
      },
      {
        name: "MAINTAINERS.md with governance",
        required: false,
        check: () => fileExists("MAINTAINERS.md"),
        points: 1,
      },
    ],
  },
  {
    category: "7. Offline-First",
    checks: [
      {
        name: "Can work without network (documented)",
        required: false,
        check: async () =>
          await fileContains("README.adoc", "offline") ||
          await fileContains("README.md", "offline"),
        points: 2,
      },
    ],
  },
  {
    category: "8. Type Safety",
    checks: [
      {
        name: "Type-safe language used",
        required: false,
        check: async () =>
          await fileExists("tsconfig.json") ||
          await fileExists("deno.json") ||
          await fileExists("bsconfig.json"),
        points: 3,
      },
    ],
  },
  {
    category: "9. Memory Safety",
    checks: [
      {
        name: "Memory-safe language (Rust/Haskell/etc.)",
        required: false,
        check: async () =>
          await fileExists("Cargo.toml") ||
          await fileExists("*.cabal"),
        points: 3,
      },
    ],
  },
  {
    category: "10. Attribution",
    checks: [
      {
        name: ".well-known/humans.txt",
        required: false,
        check: () => fileExists(".well-known/humans.txt"),
        points: 2,
      },
      {
        name: "Contributors recognized",
        required: false,
        check: () => fileContains(".well-known/humans.txt", "TEAM"),
        points: 1,
      },
    ],
  },
  {
    category: "11. AI Training Policy",
    checks: [
      {
        name: ".well-known/ai.txt",
        required: false,
        check: () => fileExists(".well-known/ai.txt"),
        points: 2,
      },
      {
        name: "AI training policy defined",
        required: false,
        check: () => fileContains(".well-known/ai.txt", "AI-Training:"),
        points: 1,
      },
    ],
  },
];

async function runCompliance() {
  console.log(`${BOLD}RSR Compliance Verification${RESET}\n`);

  let totalPoints = 0;
  let earnedPoints = 0;
  let passedChecks = 0;
  let failedChecks = 0;

  for (const category of complianceChecks) {
    console.log(`${BOLD}${category.category}${RESET}`);

    for (const check of category.checks) {
      totalPoints += check.points;
      const passed = await check.check();

      if (passed) {
        earnedPoints += check.points;
        passedChecks++;
        console.log(
          `  ${GREEN}✓${RESET} ${check.name} ${passed ? `(+${check.points})` : ""}`,
        );
      } else {
        failedChecks++;
        const marker = check.required ? `${RED}✗${RESET}` : `${YELLOW}○${RESET}`;
        const required = check.required ? " [REQUIRED]" : " [optional]";
        console.log(`  ${marker} ${check.name}${required}`);
      }
    }
    console.log("");
  }

  const percentage = Math.round((earnedPoints / totalPoints) * 100);

  console.log(`${BOLD}=== Results ===${RESET}`);
  console.log(`Passed: ${GREEN}${passedChecks}${RESET}`);
  console.log(`Failed: ${RED}${failedChecks}${RESET}`);
  console.log(`Score: ${earnedPoints}/${totalPoints} (${percentage}%)\n`);

  let tier = "Bronze";
  let tierColor = YELLOW;

  if (percentage >= 90) {
    tier = "Gold";
    tierColor = "\x1b[33m"; // Yellow/Gold
  } else if (percentage >= 80) {
    tier = "Silver";
    tierColor = "\x1b[37m"; // White/Silver
  }

  console.log(
    `${BOLD}RSR Compliance Tier: ${tierColor}${tier}${RESET} ${BOLD}(${percentage}%)${RESET}`,
  );

  if (percentage < 80) {
    console.log(
      `\n${YELLOW}Target: 80% for Silver tier, 90% for Gold tier${RESET}`,
    );
  }

  console.log(`\nFor details, see: docs/RSR-COMPLIANCE-AUDIT.adoc`);

  return percentage >= 60; // Bronze minimum
}

if (import.meta.main) {
  const success = await runCompliance();
  Deno.exit(success ? 0 : 1);
}
