-- requirement_checker.adb
-- Requirements checker for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Fixed;

package body Requirement_Checker is

   --  Check if a path exists (file or directory)
   function Path_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   end Path_Exists;

   --  Check if file contains pattern
   function File_Contains (Path : String; Pattern : String) return Boolean is
      F       : File_Type;
      Content : Unbounded_String;
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
         Append (Content, Get_Line (F));
         Append (Content, ASCII.LF);
      end loop;
      Close (F);

      return Ada.Strings.Fixed.Index (To_String (Content), Pattern) > 0;
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         return False;
   end File_Contains;

   function Check_Requirement (Req : Requirement_Def) return Check_Result is
      Path    : constant String := To_String (Req.Path);
      Pattern : constant String := To_String (Req.Pattern);
      Result  : Check_Result;
   begin
      Result.Requirement := Req;

      case Req.Kind is
         when Must_Have =>
            if Path_Exists (Path) then
               Result.Passed := True;
               Result.Message := To_Unbounded ("OK: " & Path & " exists");
            else
               Result.Passed := False;
               Result.Message := To_Unbounded ("MISSING: " & Path);
            end if;

         when Must_Not_Have =>
            if not Path_Exists (Path) then
               Result.Passed := True;
               Result.Message := To_Unbounded
                 ("OK: " & Path & " does not exist");
            else
               Result.Passed := False;
               Result.Message := To_Unbounded ("FORBIDDEN: " & Path & " exists");
            end if;

         when Must_Contain =>
            if File_Contains (Path, Pattern) then
               Result.Passed := True;
               Result.Message := To_Unbounded
                 ("OK: " & Path & " contains pattern");
            else
               Result.Passed := False;
               Result.Message := To_Unbounded
                 ("MISSING CONTENT: " & Path & " should contain: " & Pattern);
            end if;
      end case;

      return Result;
   end Check_Requirement;

   function Check_All (Config : Mustfile_Config) return Result_Vector is
      Results : Result_Vector;
   begin
      for Req of Config.Requirements loop
         Results.Append (Check_Requirement (Req));
      end loop;
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
               Put_Line ("  [PASS] " & To_String (R.Message));
            end if;
         else
            Failed_Count := Failed_Count + 1;
            Put_Line ("  [FAIL] " & To_String (R.Message));
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
                     Path : constant String := To_String (R.Requirement.Path);
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
                     Path : constant String := To_String (R.Requirement.Path);
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
                  Put_Line ("  Cannot auto-fix: " & To_String (R.Message));
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
