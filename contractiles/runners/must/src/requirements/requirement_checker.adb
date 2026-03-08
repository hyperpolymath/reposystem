-- requirement_checker.adb
-- Requirements checker for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;  -- Only for file reading buffer
use type Ada.Directories.File_Kind;

package body Requirement_Checker is

   --  Check if a path exists (file or directory)
   function Path_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   end Path_Exists;

   --  Check if file contains pattern
   function File_Contains (Path : String; Pattern : String) return Boolean is
      F       : File_Type;
      Content : Ada.Strings.Unbounded.Unbounded_String;
   begin
      if not Ada.Directories.Exists (Path) then
         return False;
      end if;

      --  Only check files, not directories
      if Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File then
         return False;
      end if;

      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Ada.Strings.Unbounded.Append (Content, Get_Line (F));
         Ada.Strings.Unbounded.Append (Content, ASCII.LF);
      end loop;
      Close (F);

      return Ada.Strings.Fixed.Index
        (Ada.Strings.Unbounded.To_String (Content), Pattern) > 0;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         return False;
   end File_Contains;

   function Check_Requirement (Req : Requirement_Def) return Check_Result is
      Path    : constant String := Must_Types.To_Path_String (Req.Path);
      Pattern : constant String := Must_Types.To_String (Req.Pattern);
      Result  : Check_Result;

      function Make_Message (Msg : String) return Bounded_Description is
      begin
         if Msg'Length > Max_Description_Length then
            return Must_Types.To_Bounded_Description
              (Msg (Msg'First .. Msg'First + Max_Description_Length - 4) & "...");
         else
            return Must_Types.To_Bounded_Description (Msg);
         end if;
      end Make_Message;
   begin
      Result.Requirement := Req;

      case Req.Kind is
         when Must_Have =>
            if Path_Exists (Path) then
               Result.Passed := True;
               Result.Message := Make_Message ("OK: " & Path & " exists");
            else
               Result.Passed := False;
               Result.Message := Make_Message ("MISSING: " & Path);
            end if;

         when Must_Not_Have =>
            if not Path_Exists (Path) then
               Result.Passed := True;
               Result.Message := Make_Message ("OK: " & Path & " does not exist");
            else
               Result.Passed := False;
               Result.Message := Make_Message ("FORBIDDEN: " & Path & " exists");
            end if;

         when Must_Contain =>
            if File_Contains (Path, Pattern) then
               Result.Passed := True;
               Result.Message := Make_Message ("OK: " & Path & " contains pattern");
            else
               Result.Passed := False;
               Result.Message := Make_Message
                 ("MISSING CONTENT: " & Path & " should contain: " & Pattern);
            end if;
      end case;

      return Result;
   end Check_Requirement;

   function Check_All (Config : Mustfile_Config) return Result_Vector is
      Results : Result_Vector;
      Req     : Requirement_Def;
   begin
      for R of Config.Requirements loop
         Req := R;
         Results.Append (Check_Requirement (Req));
      end loop;

      --  TODO: Re-add Requirements_Content support when map type is added to must_types
      --  This was used for dynamic content requirements (file → patterns mapping)
      --  For now, only static requirements from Requirements vector are checked

      return Results;
   end Check_All;

   procedure Check
     (Config  : Mustfile_Config;
      Strict  : Boolean := False;
      Verbose : Boolean := False)
   is
      Results      : constant Result_Vector := Check_All (Config);
      Passed_Count : Natural := 0;
      Failed_Count : Natural := 0;
   begin
      if Config.Requirements.Is_Empty then
         Put_Line ("No requirements defined");
         return;
      end if;

      Put_Line ("Checking requirements:");
      Put_Line ("");

      for R of Results loop
         if R.Passed then
            Passed_Count := Passed_Count + 1;
            if Verbose then
               Put_Line ("  [PASS] " & Must_Types.To_Description_String (R.Message));
            end if;
         else
            Failed_Count := Failed_Count + 1;
            Put_Line ("  [FAIL] " & Must_Types.To_Description_String (R.Message));
         end if;
      end loop;

      Put_Line ("");
      Put_Line ("Passed:" & Natural'Image (Passed_Count) &
                " / Failed:" & Natural'Image (Failed_Count));

      if Failed_Count > 0 and then Strict then
         raise Requirement_Failed with
           "Requirements check failed (" & Natural'Image (Failed_Count) &
           " violations)";
      end if;
   end Check;

   procedure Fix
     (Config  : Mustfile_Config;
      Dry_Run : Boolean := False;
      Verbose : Boolean := False)
   is
      Results     : constant Result_Vector := Check_All (Config);
      Fixed_Count : Natural := 0;
   begin
      Put_Line ("Fixing violations:");
      Put_Line ("");

      for R of Results loop
         if not R.Passed then
            case R.Requirement.Kind is
               when Must_Have =>
                  --  Create empty file/directory
                  declare
                     Path : constant String := Must_Types.To_Path_String (R.Requirement.Path);
                  begin
                     if Verbose or Dry_Run then
                        Put_Line ("  Creating: " & Path);
                     end if;

                     if not Dry_Run then
                        --  Check if it's a directory (ends with /)
                        if Path (Path'Last) = '/' then
                           Ada.Directories.Create_Path (Path);
                        else
                           --  Create empty file
                           declare
                              F : File_Type;
                           begin
                              Create (F, Out_File, Path);
                              Close (F);
                           end;
                        end if;
                        Fixed_Count := Fixed_Count + 1;
                     end if;
                  end;

               when Must_Not_Have =>
                  --  Delete file/directory
                  declare
                     Path : constant String := Must_Types.To_Path_String (R.Requirement.Path);
                  begin
                     if Verbose or Dry_Run then
                        Put_Line ("  Removing: " & Path);
                     end if;

                     if not Dry_Run then
                        if Ada.Directories.Exists (Path) then
                           if Ada.Directories.Kind (Path) =
                              Ada.Directories.Directory
                           then
                              Ada.Directories.Delete_Tree (Path);
                           else
                              Ada.Directories.Delete_File (Path);
                           end if;
                           Fixed_Count := Fixed_Count + 1;
                        end if;
                     end if;
                  end;

               when Must_Contain =>
                  --  Cannot auto-fix content requirements
                  Put_Line ("  Cannot auto-fix: " & Must_Types.To_Description_String (R.Message));
            end case;
         end if;
      end loop;

      if Dry_Run then
         Put_Line ("(dry run - no changes made)");
      else
         Put_Line ("");
         Put_Line ("Fixed:" & Natural'Image (Fixed_Count) & " violations");
      end if;
   end Fix;

   procedure Enforce
     (Config  : Mustfile_Config;
      Strict  : Boolean := True;
      Dry_Run : Boolean := False;
      Verbose : Boolean := False)
   is
   begin
      Put_Line ("=== Enforcement Mode ===");
      Put_Line ("");

      --  Step 1: Check requirements
      Put_Line ("Step 1: Check requirements");
      begin
         Check (Config, Strict => False, Verbose => Verbose);
      exception
         when others =>
            null;  --  Continue even if check fails
      end;
      Put_Line ("");

      --  Step 2: Fix violations
      Put_Line ("Step 2: Fix violations");
      Fix (Config, Dry_Run, Verbose);
      Put_Line ("");

      --  Step 3: Verify
      Put_Line ("Step 3: Verify");
      Check (Config, Strict, Verbose);
      Put_Line ("");

      Put_Line ("=== Enforcement Complete ===");
   end Enforce;

end Requirement_Checker;
