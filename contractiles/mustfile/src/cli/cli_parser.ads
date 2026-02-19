-- cli_parser.ads
-- Command-line argument parser for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

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

   --  Parsed arguments
   type Parsed_Args is record
      Command        : Command_Type := Cmd_None;
      Task_Name      : Unbounded_String;
      Template_Name  : Unbounded_String;
      Variables      : String_Map;
      Vars_File      : Unbounded_String;
      Strict         : Boolean := False;
      Dry_Run        : Boolean := False;
      Verbose        : Boolean := False;
      Extra_Args     : String_Vector;
      --  Deploy-specific options
      Deploy_Target  : Unbounded_String;  --  Target OS/container
      Deploy_Push    : Boolean := False;  --  Push to registry
      Deploy_Tag     : Unbounded_String;  --  Container tag
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
