-- mustfile_loader.ads
-- Mustfile configuration loader for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Must_Types; use Must_Types;

package Mustfile_Loader is

   --  Default mustfile name
   Mustfile_Name : constant String := "mustfile.toml";

   --  Check if mustfile exists in current directory
   function Mustfile_Exists return Boolean;

   --  Load mustfile configuration
   function Load return Mustfile_Config;

   --  Load mustfile from specific path
   function Load (Path : String) return Mustfile_Config;

   --  Create default mustfile
   procedure Create_Default_Mustfile;

   --  Create default mustfile at specific path
   procedure Create_Default_Mustfile (Path : String);

   --  Load error exception
   Load_Error : exception;

end Mustfile_Loader;
