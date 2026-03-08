-- cli_parser.adb
-- Command-line argument parser for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Ada.Command_Line;
with Ada.Text_IO; use Ada.Text_IO;
with Ada.Strings.Fixed;

package body CLI_Parser is

   Version_String : constant String := "0.1.0";

   function Get_Arguments return String_Vector is
      Args : String_Vector;
   begin
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         Args.Append (Ada.Command_Line.Argument (I));
      end loop;
      return Args;
   end Get_Arguments;

   function Parse return Parsed_Args is
      Result : Parsed_Args;
      Args   : constant String_Vector := Get_Arguments;
      I      : Positive := 1;

      procedure Parse_Var (Arg : String) is
         Eq_Pos : constant Natural :=
           Ada.Strings.Fixed.Index (Arg, "=");
      begin
         if Eq_Pos = 0 then
            raise Parse_Error with "Invalid --var format: " & Arg;
         end if;

         declare
            Key   : constant String := Arg (Arg'First .. Eq_Pos - 1);
            Value : constant String := Arg (Eq_Pos + 1 .. Arg'Last);
         begin
            Result.Variables.Include (Key, Value);
         end;
      end Parse_Var;

   begin
      if Args.Is_Empty then
         Result.Command := Cmd_None;
         return Result;
      end if;

      while I <= Natural (Args.Length) loop
         declare
            Arg : constant String := Args (I);
         begin
            if Arg = "--help" or else Arg = "-h" then
               Result.Command := Cmd_Help;
               return Result;

            elsif Arg = "--version" or else Arg = "-v" then
               Result.Command := Cmd_Version;
               return Result;

            elsif Arg = "--list" or else Arg = "-l" then
               Result.Command := Cmd_List;

            elsif Arg = "--strict" then
               Result.Strict := True;

            elsif Arg = "--dry-run" then
               Result.Dry_Run := True;

            elsif Arg = "--verbose" or else Arg = "-V" then
               Result.Verbose := True;

            elsif Arg = "--template" then
               I := I + 1;
               if I > Natural (Args.Length) then
                  raise Parse_Error with "--template requires an argument";
               end if;
               Result.Template_Name := To_Unbounded (Args (I));

            elsif Arg = "--var" then
               I := I + 1;
               if I > Natural (Args.Length) then
                  raise Parse_Error with "--var requires KEY=VALUE argument";
               end if;
               Parse_Var (Args (I));

            elsif Arg = "--vars" then
               I := I + 1;
               if I > Natural (Args.Length) then
                  raise Parse_Error with "--vars requires a file argument";
               end if;
               Result.Vars_File := To_Unbounded (Args (I));

            elsif Arg = "init" then
               Result.Command := Cmd_Init;

            elsif Arg = "apply" then
               Result.Command := Cmd_Apply;

            elsif Arg = "check" then
               Result.Command := Cmd_Check;

            elsif Arg = "fix" then
               Result.Command := Cmd_Fix;

            elsif Arg = "enforce" then
               Result.Command := Cmd_Enforce;

            elsif Arg = "templates" then
               Result.Command := Cmd_Templates;

            elsif Arg = "deploy" then
               Result.Command := Cmd_Deploy;

            elsif Arg = "--target" then
               I := I + 1;
               if I > Natural (Args.Length) then
                  raise Parse_Error with "--target requires an argument";
               end if;
               Result.Deploy_Target := To_Unbounded (Args (I));

            elsif Arg = "--tag" then
               I := I + 1;
               if I > Natural (Args.Length) then
                  raise Parse_Error with "--tag requires an argument";
               end if;
               Result.Deploy_Tag := To_Unbounded (Args (I));

            elsif Arg = "--push" then
               Result.Deploy_Push := True;

            elsif Arg'Length > 0 and then Arg (Arg'First) = '-' then
               raise Parse_Error with "Unknown option: " & Arg;

            else
               --  Task name or extra argument
               if Result.Command = Cmd_None then
                  Result.Command := Cmd_Run_Task;
                  Result.Task_Name := To_Unbounded (Arg);
               else
                  Result.Extra_Args.Append (Arg);
               end if;
            end if;

            I := I + 1;
         end;
      end loop;

      return Result;
   end Parse;

   procedure Show_Help is
   begin
      Put_Line ("Must v" & Version_String);
      Put_Line ("Task runner + template engine + project enforcer");
      Put_Line ("");
      Put_Line ("Usage: must [COMMAND] [OPTIONS]");
      Put_Line ("");
      Put_Line ("Commands:");
      Put_Line ("  <task>              Run a task from mustfile.toml");
      Put_Line ("  --list, -l          List all available tasks");
      Put_Line ("  apply               Apply templates");
      Put_Line ("  check               Check requirements");
      Put_Line ("  fix                 Fix violations automatically");
      Put_Line ("  enforce             Check + apply + verify");
      Put_Line ("  deploy              Build and deploy via Containerfile");
      Put_Line ("  init                Create default mustfile.toml");
      Put_Line ("  templates           List available templates");
      Put_Line ("  --help, -h          Show this help");
      Put_Line ("  --version, -v       Show version");
      Put_Line ("");
      Put_Line ("Options:");
      Put_Line ("  --strict            Fail on requirement violations");
      Put_Line ("  --dry-run           Show what would be executed");
      Put_Line ("  --verbose, -V       Verbose output");
      Put_Line ("  --template NAME     Apply specific template");
      Put_Line ("  --var KEY=VALUE     Set template variable");
      Put_Line ("  --vars FILE         Load variables from TOML file");
      Put_Line ("");
      Put_Line ("Deploy Options:");
      Put_Line ("  --target TARGET     Target (container, local)");
      Put_Line ("  --tag TAG           Container image tag (default: latest)");
      Put_Line ("  --push              Push image to registry after build");
      Put_Line ("");
      Put_Line ("Examples:");
      Put_Line ("  must build          Run the 'build' task");
      Put_Line ("  must --list         List all tasks");
      Put_Line ("  must apply --template ada_package --var module=Test");
      Put_Line ("  must check --strict");
      Put_Line ("  must deploy         Build container from Containerfile");
      Put_Line ("  must deploy --tag v1.0 --push");
   end Show_Help;

   procedure Show_Version is
   begin
      Put_Line ("must " & Version_String);
   end Show_Version;

end CLI_Parser;
