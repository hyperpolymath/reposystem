-- mustache_engine.ads
-- Mustache template engine for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Must_Types; use Must_Types;

package Mustache_Engine is

   --  Render a template string with variables
   function Render
     (Template  : String;
      Variables : String_Map) return String;

   --  Render a template file with variables
   function Render_File
     (Template_Path : String;
      Variables     : String_Map) return String;

   --  Apply a template to generate output file
   procedure Apply_Template
     (Source      : String;
      Destination : String;
      Variables   : String_Map;
      Dry_Run     : Boolean := False;
      Verbose     : Boolean := False);

   --  Apply all templates from config
   procedure Apply_All
     (Config  : Mustfile_Config;
      Dry_Run : Boolean := False;
      Verbose : Boolean := False);

   --  Apply a specific template by name
   procedure Apply_Named
     (Config        : Mustfile_Config;
      Template_Name : String;
      Variables     : String_Map;
      Dry_Run       : Boolean := False;
      Verbose       : Boolean := False);

   --  List available templates
   procedure List_Templates (Config : Mustfile_Config);

   --  Check if template exists
   function Template_Exists
     (Config        : Mustfile_Config;
      Template_Name : String) return Boolean;

   --  Template error
   Template_Error : exception;

end Mustache_Engine;
