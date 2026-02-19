-- cli_parser.ads
-- Command-line argument parser for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Must_Types; use Must_Types;

package CLI_Parser is

   --  Command types
   type Command_Type is
     (Cmd_None,
      Cmd_Help,
      Cmd_Version,
      Cmd_List,
      Cmd_Init,
      Cmd_Run_Task,
      Cmd_Apply,
      Cmd_Check,
      Cmd_Fix,
      Cmd_Enforce,
      Cmd_Templates,
      Cmd_Deploy);

   --  Parsed arguments (now using bounded strings for safety)
   type Parsed_Args is record
      Command        : Command_Type := Cmd_None;
      Task_Name      : Bounded_String;
      Template_Name  : Bounded_String;
      Variables      : String_Map;
      Vars_File      : Bounded_Path;  -- File paths can be long
      Strict         : Boolean := False;
      Dry_Run        : Boolean := False;
      Verbose        : Boolean := False;
      Extra_Args     : String_Vector;
      --  Deploy-specific options
      Deploy_Target  : Bounded_String;  --  Target OS/container
      Deploy_Push    : Boolean := False;  --  Push to registry
      Deploy_Tag     : Bounded_String;  --  Container tag
   end record;

   --  Parse command-line arguments
   function Parse return Parsed_Args;

   --  Get raw arguments as a vector
   function Get_Arguments return String_Vector;

   --  Show help text
   procedure Show_Help;

   --  Show version
   procedure Show_Version;

   --  Parse error exception
   Parse_Error : exception;

end CLI_Parser;
