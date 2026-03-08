-- requirement_checker.ads
-- Requirements checker for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Containers.Vectors;
with Must_Types; use Must_Types;

package Requirement_Checker is

   --  Check result (using bounded strings for safety)
   type Check_Result is record
      Passed      : Boolean;
      Message     : Bounded_Description;  -- Messages can be moderately long
      Requirement : Requirement_Def;
   end record;

   --  Check result vector
   package Result_Vectors is new Ada.Containers.Vectors
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
