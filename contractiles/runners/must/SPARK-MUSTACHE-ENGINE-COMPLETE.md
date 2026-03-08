# mustache_engine Conversion Complete

**Date:** 2026-02-05
**Session:** Phase 6 - mustache_engine
**Status:** ✅ COMPLETE

---

## Summary

Successfully converted mustache_engine to use bounded strings. The template rendering engine now uses memory-safe bounded types for all variable lookups and string operations.

---

## Files Modified

### mustache_engine.ads
**Changes:**
- Fixed license header (`AGPL-3.0-or-later` → `MPL-2.0`)
- No API changes needed (already used String_Map from must_types)

### mustache_engine.adb
**Changes:**
- Fixed license header
- Added `use Ada.Strings.Unbounded` for HTML escaping buffer
- Created helper functions for String→Bounded_String key lookups:
  ```ada
  function Get_Var (Variables : String_Map; Key : String) return String is
     Bounded_Key : Bounded_String;
  begin
     if Key'Length > Max_String_Length then
        return "";
     end if;
     Bounded_Key := Must_Types.To_Bounded (Key);
     if Variables.Contains (Bounded_Key) then
        return Must_Types.To_String (Variables.Element (Bounded_Key));
     else
        return "";
     end if;
  end Get_Var;

  function Has_Var (Variables : String_Map; Key : String) return Boolean is
     Bounded_Key : Bounded_String;
  begin
     if Key'Length > Max_String_Length then
        return False;
     end if;
     Bounded_Key := Must_Types.To_Bounded (Key);
     return Variables.Contains (Bounded_Key);
  end Has_Var;
  ```

- **Render function updates:**
  - Line 171: `Variables.Contains (Name)` → `Has_Var (Variables, Name)`
  - Line 173: `Variables (Name)` → `Get_Var (Variables, Name)`
  - Line 201: `Variables.Contains (Name)` → `Has_Var (Variables, Name)`
  - Line 202-203: `Variables (Name)` → `Get_Var (Variables, Name)`
  - Line 252: `Variables.Contains (Name)` → `Has_Var (Variables, Name)`
  - Line 253: `Variables (Name)` → `Get_Var (Variables, Name)`
  - Line 264-268: Simplified and used `Has_Var`/`Get_Var`
  - Line 279: `Variables.Contains (Name)` → `Has_Var (Variables, Name)`
  - Line 282: `Variables (Name)` → `Get_Var (Variables, Name)`

- **Apply_All procedure:**
  - Line 349: Added `constant` qualifier to Variables
  - Line 360-361: `To_String (T.Source/Destination)` → `To_Path_String (T.Source/Destination)`

- **Apply_Named procedure:**
  - Line 393-394: `To_String (T.Source/Destination)` → `To_Path_String (T.Source/Destination)`

- **List_Templates procedure:**
  - Line 421-422: `Length (T.Name)` → `Must_Types.Bounded_Strings.Length (T.Name)`
  - Line 432: `To_String (T.Description)` → `To_Description_String (T.Description)`
  - Line 433: Array aggregate `(others => ' ')` → `[others => ' ']`

---

## Safety Improvements

### String Key Lookup Safety
```ada
function Get_Var (Variables : String_Map; Key : String) return String is
   Bounded_Key : Bounded_String;
begin
   if Key'Length > Max_String_Length then
      return "";  -- Safe default for oversized keys
   end if;
   Bounded_Key := Must_Types.To_Bounded (Key);
   if Variables.Contains (Bounded_Key) then
      return Must_Types.To_String (Variables.Element (Bounded_Key));
   else
      return "";  -- Safe default for missing keys
   end if;
end Get_Var;
```
- Keys bounded to `Max_String_Length` (1024 chars)
- Oversized keys return empty string instead of raising exception
- Missing keys return empty string (graceful degradation)
- No direct string access to map (all through helper functions)

### Type Safety
- Template source/destination paths: `Bounded_Path` (4096 chars)
- Template names: `Bounded_String` (1024 chars)
- Template descriptions: `Bounded_Description` (2048 chars)
- Variable keys/values: `Bounded_String` (1024 chars)
- All conversions explicit and checked

### HTML Escaping
```ada
--  HTML escape the value (basic escaping)
declare
   Value   : constant String := Get_Var (Variables, Name);
   Escaped : Unbounded_String;  -- Still used for internal buffer
begin
   for C of Value loop
      case C is
         when '&' => Append (Escaped, "&amp;");
         when '<' => Append (Escaped, "&lt;");
         when '>' => Append (Escaped, "&gt;");
         when '"' => Append (Escaped, "&quot;");
         when others => Append (Escaped, C);
      end case;
   end loop;
   Append (Result, Ada.Strings.Unbounded.To_String (Escaped));
end;
```
- HTML entities properly escaped
- Temporary buffer uses Unbounded_String (not exposed in API)
- Final result appended to bounded result buffer

---

## Compilation Results

### ✅ Success
```bash
$ gprbuild -P must.gpr -c -u src/templates/mustache_engine.adb
Compile
   [Ada]          mustache_engine.adb
# SUCCESS - zero errors, zero warnings!
```

---

## Modules Complete

| Module | Status | Errors | Notes |
|--------|--------|--------|-------|
| **must_types** | ✅ COMPLETE | 0 | Foundation |
| **cli_parser** | ✅ COMPLETE | 0 | Argument parsing |
| **must** | ✅ COMPLETE | 0 | Main program |
| **task_runner** | ✅ COMPLETE | 0 | Task execution |
| **requirement_checker** | ✅ COMPLETE | 0 | File system checks |
| **mustfile_loader** | ✅ COMPLETE | 0 | TOML parsing |
| **mustache_engine** | ✅ COMPLETE | 0 | **Just completed!** |
| **deployer** | ⏳ TODO | ~4 warnings | Container deployment |
| **toml_parser** | ⏳ TODO | ? | Likely included in mustfile_loader |

---

## Progress

**Complete:** 7/9 modules (~78%)
- must_types ✅
- cli_parser ✅
- must.adb ✅
- task_runner ✅
- requirement_checker ✅
- mustfile_loader ✅
- mustache_engine ✅

**Remaining:** deployer, toml_parser

---

## Key Accomplishments

### 1. Template Variable Lookup Safety
All variable lookups go through helper functions that:
- Validate key length before lookup
- Return safe defaults for missing/oversized keys
- Convert between String and Bounded_String transparently
- Maintain template parsing logic without major refactoring

### 2. Path Type Safety
```ada
Apply_Template
  (Source      => Must_Types.To_Path_String (T.Source),
   Destination => Must_Types.To_Path_String (T.Destination),
   Variables   => Variables,
   Dry_Run     => Dry_Run,
   Verbose     => Verbose);
```
- Source and destination paths properly typed as `Bounded_Path`
- Explicit conversion to String at usage point
- No implicit conversions between path and string types

### 3. Description Type Safety
```ada
Desc : constant String := Must_Types.To_Description_String (T.Description);
```
- Template descriptions properly typed as `Bounded_Description`
- Explicit conversion functions for each bounded type
- Compiler enforces correct type usage

---

## Next Steps

### Phase 7: Convert deployer (Optional)

**~4 warnings to fix:**
- Likely similar issues: type conversions, array aggregates
- Container deployment functionality

**Strategy:**
1. Fix license header
2. Update to use bounded string types
3. Fix any type conversion warnings
4. Fix array aggregate syntax

### Phase 8: Verify full build

**Test complete build:**
```bash
gprbuild -P must.gpr
```

**Expected:**
- All modules compile successfully
- Zero errors across codebase
- Ready for SPARK verification (when GNATprove installed)

---

## Session Summary

✅ **mustache_engine converted** (0 errors, 0 warnings!)
✅ **Template rendering** now memory-safe
✅ **Variable lookups** bounds-checked
✅ **Path operations** type-safe
🎯 **Next:** deployer conversion (optional)

**Progress:** ~78% of codebase converted (7/9 modules)
