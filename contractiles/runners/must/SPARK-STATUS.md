# SPARK Conversion Status

**Date:** 2026-02-05
**Project:** must - Task runner + template engine + enforcer
**Goal:** Convert Ada 2022 codebase to SPARK for formal verification

---

## Overview

SPARK is a formally verifiable subset of Ada that enables mathematical proof of program correctness. By converting the must binary to SPARK, we gain:

- **Formal verification** of contracts (preconditions, postconditions)
- **Proven absence** of runtime errors (buffer overflows, null pointers, etc.)
- **Type invariants** enforced at compile-time
- **Memory safety** guarantees
- **Higher assurance** for critical deployment operations

---

## Conversion Strategy

### Phase 1: Type System (COMPLETE ✅)

**Files converted:**
- `src/must_types.ads` - Type definitions with SPARK contracts
- `src/must_types.adb` - Body (minimal, all in spec)
- `must.gpr` - Added GNATprove configuration

**Key changes:**

1. **Bounded Strings** - Replaced `Unbounded_String` with bounded variants:
   ```ada
   Max_Path_Length        : constant := 4096;
   Max_String_Length      : constant := 1024;
   Max_Command_Length     : constant := 8192;
   Max_Description_Length : constant := 2048;

   package Bounded_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_String_Length);
   subtype Bounded_String is Bounded_Strings.Bounded_String;
   ```

2. **Formal Containers** - Replaced indefinite containers with formal versions:
   ```ada
   -- Before (Ada 2022):
   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   -- After (SPARK):
   package String_Vectors is new Ada.Containers.Formal_Vectors
     (Index_Type => Positive, Element_Type => Bounded_String);
   ```

3. **Type Predicates** - Added invariants to all major types:
   ```ada
   type Task_Def is record
      Name         : Bounded_String;
      Description  : Bounded_Description;
      Commands     : Command_Vector;
      Dependencies : String_Vector;
      Script       : Bounded_Command;
      Working_Dir  : Bounded_Path;
   end record with
      Predicate => Bounded_Strings.Length (Task_Def.Name) > 0;
      -- Task must have a non-empty name
   ```

4. **Pre/Post Conditions** - Added contracts to conversion functions:
   ```ada
   function To_Bounded (S : String) return Bounded_String is
     (Bounded_Strings.To_Bounded_String (S)) with
      Pre  => S'Length <= Max_String_Length,
      Post => Bounded_Strings.To_String (To_Bounded'Result) = S;
   ```

5. **SPARK_Mode** - Enabled SPARK checking:
   ```ada
   pragma SPARK_Mode (On);
   package Must_Types with SPARK_Mode => On is
   ```

### Phase 2: Main Program (TODO)

**Files to convert:**
- `src/must.adb` - Main entry point

**Required changes:**
- Add `pragma SPARK_Mode (On);`
- Convert exception handlers to precondition checks where possible
- Add pre/postconditions to main logic blocks
- Ensure all paths are provably safe

**Challenges:**
- Exception handling in SPARK (limited support)
- I/O operations require careful contracts
- Command_Line operations need safety proofs

### Phase 3: CLI Parser (TODO)

**Files to convert:**
- `src/cli/cli_parser.ads`
- `src/cli/cli_parser.adb`

**Required changes:**
- Convert argument parsing to bounded strings
- Add preconditions for valid argument counts
- Prove no buffer overflows in string operations
- Add invariants for Parsed_Args type

### Phase 4: Mustfile Loader (TODO)

**Files to convert:**
- `src/config/mustfile_loader.ads`
- `src/config/mustfile_loader.adb`
- `src/config/toml_parser.ads`
- `src/config/toml_parser.adb`

**Required changes:**
- File I/O with SPARK contracts
- TOML parsing with bounded strings
- Prove correctness of parser state machine
- Handle parse errors without exceptions

### Phase 5: Task Runner (TODO)

**Files to convert:**
- `src/tasks/task_runner.ads`
- `src/tasks/task_runner.adb`

**Required changes:**
- Dependency resolution with formal verification
- Prove absence of circular dependencies
- Safe command execution with contracts
- Process spawning with error handling

### Phase 6: Requirement Checker (TODO)

**Files to convert:**
- `src/requirements/requirement_checker.ads`
- `src/requirements/requirement_checker.adb`

**Required changes:**
- File system operations with SPARK contracts
- Pattern matching with proofs
- Requirement validation logic
- Safe fix operations

### Phase 7: Template Engine (TODO)

**Files to convert:**
- `src/templates/mustache_engine.ads`
- `src/templates/mustache_engine.adb`

**Required changes:**
- Mustache template parsing
- Variable substitution with bounds checking
- Template rendering with formal verification
- File writing with safety proofs

### Phase 8: Deployer (TODO)

**Files to convert:**
- `src/deploy/deployer.ads`
- `src/deploy/deployer.adb`

**Required changes:**
- Deployment orchestration contracts
- Container/package manager integration
- Safe command execution
- Rollback safety proofs

---

## Verification Commands

### Build with SPARK
```bash
gprbuild -P must.gpr -XMODE=debug
```

### Run GNATprove
```bash
gnatprove -P must.gpr
```

### Full verification (maximum level)
```bash
gnatprove -P must.gpr --level=4 --timeout=60
```

### Check specific file
```bash
gnatprove -P must.gpr -u must_types.ads --level=4
```

---

## Current Status

| Module | Status | Compiles | Errors | Notes |
|--------|--------|----------|--------|-------|
| **must_types** | ✅ COMPLETE | ✅ YES | 0 | Bounded strings, type predicates |
| **cli_parser** | ✅ COMPLETE | ✅ YES | 0 | Safe argument parsing |
| **must** | ✅ COMPLETE | ✅ YES | 0 | Main program with bounded strings |
| **task_runner** | 🔄 IN PROGRESS | ❌ NO | 32+ | String/Unbounded conversions needed |
| **mustfile_loader** | ⏳ TODO | ❓ Unknown | ? | After task_runner |
| **toml_parser** | ⏳ TODO | ❓ Unknown | ? | After mustfile_loader |
| **requirement_checker** | ⏳ TODO | ❓ Unknown | ? | After toml_parser |
| **mustache_engine** | ⏳ TODO | ❓ Unknown | ? | After requirement_checker |
| **deployer** | ⏳ TODO | ❓ Unknown | ? | After mustache_engine |

### Compilation Status

```bash
# Phase 1 & 2 Complete! ✅
gprbuild -P must.gpr -c -u must_types.ads   # ✅ SUCCESS
gprbuild -P must.gpr -c -u cli_parser.adb   # ✅ SUCCESS
gprbuild -P must.gpr -c -u must.adb         # ✅ SUCCESS

# Phase 3: task_runner (IN PROGRESS)
gprbuild -P must.gpr -XMODE=debug
# task_runner.adb: 32+ errors
# - String operator visibility issues
# - Unbounded_String → Bounded_String conversions needed
# - Bounded_Path, Bounded_Command usage needed
```

**Progress:** 3/9 modules complete (~33%)

---

## Benefits Once Complete

### Proven Properties

1. **Memory Safety**
   - No buffer overflows
   - No null pointer dereferences
   - No use-after-free errors
   - Bounds checked array access

2. **Type Safety**
   - All type invariants maintained
   - No invalid discriminant values
   - Controlled variant record access
   - Safe type conversions

3. **Logical Correctness**
   - Preconditions always met before function calls
   - Postconditions always satisfied after function returns
   - Loop invariants maintained across iterations
   - No integer overflow/underflow

4. **Absence of Runtime Errors**
   - Mathematically proven absence of:
     - Constraint_Error
     - Storage_Error
     - Program_Error
   - All exceptions are intentional and documented

### Deployment Confidence

With SPARK verification:
- **High assurance** deployment operations won't corrupt systems
- **Proven** requirement checking won't miss violations
- **Guaranteed** task dependencies are correctly resolved
- **Verified** template rendering won't produce malformed output

---

## SPARK Tools Installation

**Current Status:** GNATprove not installed on system

To enable full SPARK verification:

```bash
# Option 1: Install SPARK Community Edition
# Download from: https://www.adacore.com/download

# Option 2: Use Alire package manager
alr get spark2014
alr with spark2014

# Option 3: Install via system package manager (if available)
# Fedora: sudo dnf install spark2014
```

Once SPARK tools are installed, formal verification can begin:
```bash
gnatprove -P must.gpr --level=4
```

## Next Steps

1. **Install SPARK tools** (gnatprove, why3, alt-ergo)
2. **Convert must.adb**: Fix 4 Unbounded_String → Bounded_String conversions
   - Line 72: `Must_Types.To_String (Args.Task_Name)`
   - Line 101: `Must_Types.To_String (Args.Template_Name)`
   - Line 184: `Must_Types.To_String (Args.Deploy_Target)`
   - Line 185: `Must_Types.To_String (Args.Deploy_Tag)`
3. **Convert CLI_Parser**: Update Parsed_Args to use Bounded_String
4. **Incremental conversion**: Convert remaining modules systematically
5. **Run GNATprove**: Verify each module as converted
6. **Document proofs**: Explain complex proof obligations
7. **CI integration**: Add GNATprove to RSR workflows

---

## Resources

- **SPARK Documentation**: https://docs.adacore.com/live/wave/spark2014/html/spark2014_ug/
- **SPARK by Example**: https://github.com/AdaCore/spark-by-example
- **Learn SPARK**: https://learn.adacore.com/courses/SPARK_for_the_MISRA_C_Developer/

---

**Status**: Phase 1 complete (must_types). Ready for verification and Phase 2 (must.adb).
