# task_runner Conversion Complete

**Date:** 2026-02-05
**Session:** Phase 3 - task_runner
**Status:** ✅ COMPLETE

---

## Summary

Successfully converted task_runner to use bounded strings. The task execution and dependency resolution engine now uses memory-safe bounded types throughout.

---

## Files Modified

### task_runner.ads
**Changes:**
- Fixed license header (`AGPL-3.0-or-later` → `MPL-2.0`)
- Updated all API functions to use `Bounded_String` instead of `String`:
  ```ada
  procedure Run_Task
    (Config    : Mustfile_Config;
     Task_Name : Bounded_String;  -- was String
     Dry_Run   : Boolean := False;
     Verbose   : Boolean := False);

  function Task_Exists
    (Config    : Mustfile_Config;
     Task_Name : Bounded_String) return Boolean;  -- was String

  function Get_Task
    (Config    : Mustfile_Config;
     Task_Name : Bounded_String) return Task_Def;  -- was String

  function Resolve_Dependencies
    (Config    : Mustfile_Config;
     Task_Name : Bounded_String) return String_Vector;  -- was String
  ```

### task_runner.adb
**Changes:**
- Fixed license header
- Removed `Ada.Strings.Unbounded` dependency
- Added `use type Bounded_String` for operator visibility
- Updated `Contains` function to use `Bounded_String`
- Updated all functions to use bounded strings:
  - `Task_Exists`: Direct comparison of `T.Name = Task_Name` (both Bounded_String)
  - `Get_Task`: Direct comparison, no string conversions needed
  - `DFS`: Uses `Bounded_String` for all task names
  - `Resolve_Dependencies`: Uses `Bounded_String` parameter

- Updated `Execute_Command` to use `Bounded_Command`:
  ```ada
  function Execute_Command
    (Command : Bounded_Command;  -- was String
     Verbose : Boolean) return Integer
  is
     Cmd_String : constant String := Must_Types.To_Command_String (Command);
  ```

- Updated `Execute_Task` to use bounded string Length functions:
  ```ada
  if Bounded_Paths.Length (T.Working_Dir) > 0 then
     Put_Line ("  cd " & Must_Types.To_Path_String (T.Working_Dir));
     Ada.Directories.Set_Directory (Must_Types.To_Path_String (T.Working_Dir));
  end if;

  if Bounded_Commands.Length (T.Script) > 0 then
     Status := Execute_Command (T.Script, Verbose);
  ```

- Updated `Run_Task` to use `Bounded_String`:
  ```ada
  for Name of Execution_Order loop
     if Name = Task_Name then
        Put_Line ("Running: " & Must_Types.To_String (Name));
     else
        Put_Line ("Running dependency: " & Must_Types.To_String (Name));
     end if;
  ```

- Updated `List_Tasks` to use bounded string Length:
  ```ada
  if Bounded_Strings.Length (T.Name) > Max_Len then
     Max_Len := Bounded_Strings.Length (T.Name);
  end if;

  Desc : constant String := Must_Types.To_Description_String (T.Description);
  ```

- Fixed Ada 2022 syntax: `(others => ' ')` → `[others => ' ']`
- Added `pragma Unreferenced` for unused parameters

### must.adb
**Changes:**
- Updated to pass `Args.Task_Name` directly (already `Bounded_String`):
  ```ada
  -- Before:
  declare
     Task_Name : constant String := Must_Types.To_String (Args.Task_Name);
  begin
     if not Task_Runner.Task_Exists (Config, Task_Name) then
        ...
     end if;
     Task_Runner.Run_Task (Config, Task_Name, ...);
  end;

  -- After:
  if not Task_Runner.Task_Exists (Config, Args.Task_Name) then
     Put_Line ("Error: Unknown task '" & Must_Types.To_String (Args.Task_Name) & "'");
     ...
  end if;
  Task_Runner.Run_Task (Config, Args.Task_Name, ...);
  ```

---

## Safety Improvements

### Type Safety
- Task names now bounded at `Max_String_Length` (1024 chars)
- Commands bounded at `Max_Command_Length` (8192 chars)
- Working directories bounded at `Max_Path_Length` (4096 chars)
- No implicit string conversions - all conversions explicit and checked

### Dependency Resolution Safety
```ada
function Contains (Vec : String_Vector; Name : Bounded_String) return Boolean
```
- Direct comparison of bounded strings
- No string copying or conversions in hot path
- Circular dependency detection uses bounded strings

### Command Execution Safety
```ada
function Execute_Command
  (Command : Bounded_Command;
   Verbose : Boolean) return Integer
```
- Command length validated before execution
- No buffer overflows possible
- Shell command string generation checked

---

## Compilation Results

### ✅ Success
```bash
$ gprbuild -P must.gpr -c -u task_runner.adb
Compile
   [Ada]          task_runner.adb
# SUCCESS - no errors, no warnings!
```

### ✅ Integration
```bash
$ gprbuild -P must.gpr -c -u must.adb
Compile
   [Ada]          must.adb
# SUCCESS - must.adb updated and compiles!
```

### ❌ Next Modules
Full build reveals remaining modules need conversion:
- **requirement_checker** - 19+ errors
- **mustache_engine** - 20+ errors
- **mustfile_loader** - 15+ errors
- **deployer** - warnings only (minor issues)

---

## Modules Complete

| Module | Status | Errors | Notes |
|--------|--------|--------|-------|
| **must_types** | ✅ COMPLETE | 0 | Foundation |
| **cli_parser** | ✅ COMPLETE | 0 | Argument parsing |
| **must** | ✅ COMPLETE | 0 | Main program |
| **task_runner** | ✅ COMPLETE | 0 | **Just completed!** |
| **requirement_checker** | 🔄 NEXT | 19+ | File system checks |
| **mustache_engine** | ⏳ TODO | 20+ | Template rendering |
| **mustfile_loader** | ⏳ TODO | 15+ | TOML parsing |
| **deployer** | ⏳ TODO | ~5 warnings | Container deployment |
| **toml_parser** | ⏳ TODO | ? | Likely included in mustfile_loader |

---

## Progress

**Complete:** 4/9 modules (~44%)
- must_types ✅
- cli_parser ✅
- must.adb ✅
- task_runner ✅

**In Progress:** requirement_checker (~19 errors)

**Remaining:** mustache_engine, mustfile_loader, deployer, toml_parser

---

## Key Accomplishments

### 1. Zero String Conversions in Hot Path
Dependency resolution and task lookup now use direct `Bounded_String` comparisons:
```ada
for T of Config.Tasks loop
   if T.Name = Task_Name then  -- Direct comparison, no conversion!
      return T;
   end if;
end loop;
```

### 2. Safe Command Execution
```ada
Status := Execute_Command (T.Script, Verbose);
-- T.Script is Bounded_Command, validated at parse time
```

### 3. Type-Safe Dependencies
```ada
for Dep of T.Dependencies loop
   if not Task_Exists (Config, Dep) then  -- Dep is Bounded_String
      raise Task_Error with
        "Task '" & Must_Types.To_String (Task_Name) &
        "' depends on unknown task: " & Must_Types.To_String (Dep);
   end if;
```

---

## Next Steps

### Phase 4: Convert requirement_checker

**19+ errors to fix:**
- Bounded_Path vs Bounded_String type mismatches
- `To_Unbounded` calls → `To_Bounded` conversions
- `Requirements_Content` field removed (needs to be added back or handled differently)
- `String_Vector_Maps` usage
- String concatenation operator visibility

**Strategy:**
1. Fix license header
2. Remove `Ada.Strings.Unbounded`
3. Add `use type` clauses
4. Convert file path operations to `Bounded_Path`
5. Update pattern matching to use `Bounded_String`
6. Fix `Requirements_Content` (if needed, add back to Mustfile_Config)

---

## Session Summary

✅ **task_runner converted** (0 errors!)
✅ **must.adb updated** (0 errors!)
✅ **Dependency resolution** now memory-safe
✅ **Command execution** bounds-checked
🎯 **Next:** requirement_checker conversion

**Progress:** ~44% of codebase converted (4/9 modules)
