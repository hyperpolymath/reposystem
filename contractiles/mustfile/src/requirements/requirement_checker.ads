-- requirement_checker.ads
-- Requirements checker for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Containers.Indefinite_Vectors;
with Must_Types; use Must_Types;

package Requirement_Checker is

   --  Check result
   type Check_Result is record
      Passed      : Boolean;
      Message     : Unbounded_String;
      Requirement : Requirement_Def;
   end record;

   --  Check result vector
   package Result_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Check_Result);

   subtype Result_Vector is Result_Vectors.Vector;

   --  Check all requirements
   function Check_All
     (Config : Mustfile_Config) return Result_Vector;

   --  Check requirements and report
   procedure Check
     (Config  : Mustfile_Config;
      Strict  : Boolean := False;
      Verbose : Boolean := False);

   --  Fix violations (where possible)
   procedure Fix
     (Config  : Mustfile_Config;
      Dry_Run : Boolean := False;
      Verbose : Boolean := False);

   --  Full enforcement (check + apply + verify)
   procedure Enforce
     (Config  : Mustfile_Config;
      Strict  : Boolean := True;
      Dry_Run : Boolean := False;
      Verbose : Boolean := False);

   --  Check a single requirement
   function Check_Requirement (Req : Requirement_Def) return Check_Result;

   --  Requirement check failed
   Requirement_Failed : exception;

end Requirement_Checker;
