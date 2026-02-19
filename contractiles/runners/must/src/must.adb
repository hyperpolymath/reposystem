--  must.adb
--  Main entry point for Must - task runner + template engine + enforcer
--  Copyright (C) 2025 Jonathan D.A. Jewell
--  SPDX-License-Identifier: MPL-2.0-or-later

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line;
with Ada.Exceptions;

with Must_Types; use Must_Types;
with CLI_Parser; use CLI_Parser;
with Mustfile_Loader;
with Task_Runner;
with Mustache_Engine;
with Requirement_Checker;
with Deployer;

procedure Must is
begin
   declare
      Args   : constant Parsed_Args := Parse;
      Config : Mustfile_Config;
   begin
      case Args.Command is
         when Cmd_Help =>
            Show_Help;

         when Cmd_Version =>
            Show_Version;

         when Cmd_Init =>
            if Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml already exists");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            else
               Mustfile_Loader.Create_Default_Mustfile;
            end if;

         when Cmd_None =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Put_Line ("Run 'must init' to create one");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            else
               Put_Line ("Error: No command specified");
               Put_Line ("Run 'must --help' for usage");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end if;

         when Cmd_List =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;
            Task_Runner.List_Tasks (Config);

         when Cmd_Run_Task =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;

            if not Task_Runner.Task_Exists (Config, Args.Task_Name) then
               Put_Line ("Error: Unknown task '" & Must_Types.To_String (Args.Task_Name) & "'");
               Put_Line ("Run 'must --list' to see available tasks");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Task_Runner.Run_Task
              (Config    => Config,
               Task_Name => Args.Task_Name,
               Dry_Run   => Args.Dry_Run,
               Verbose   => Args.Verbose);

         when Cmd_Apply =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;

            if Bounded_Strings.Length (Args.Template_Name) > 0 then
               --  Apply specific template
               Mustache_Engine.Apply_Named
                 (Config        => Config,
                  Template_Name => Must_Types.To_String (Args.Template_Name),
                  Variables     => Args.Variables,
                  Dry_Run       => Args.Dry_Run,
                  Verbose       => Args.Verbose);
            else
               --  Apply all templates
               Mustache_Engine.Apply_All
                 (Config  => Config,
                  Dry_Run => Args.Dry_Run,
                  Verbose => Args.Verbose);
            end if;

         when Cmd_Check =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;
            begin
               Requirement_Checker.Check
                 (Config  => Config,
                  Strict  => Args.Strict,
                  Verbose => Args.Verbose);
            exception
               when Requirement_Checker.Requirement_Failed =>
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end;

         when Cmd_Fix =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;
            Requirement_Checker.Fix
              (Config  => Config,
               Dry_Run => Args.Dry_Run,
               Verbose => Args.Verbose);

         when Cmd_Enforce =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;
            begin
               Requirement_Checker.Enforce
                 (Config  => Config,
                  Strict  => Args.Strict,
                  Dry_Run => Args.Dry_Run,
                  Verbose => Args.Verbose);
            exception
               when Requirement_Checker.Requirement_Failed =>
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end;

         when Cmd_Templates =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;
            Mustache_Engine.List_Templates (Config);

         when Cmd_Deploy =>
            if not Mustfile_Loader.Mustfile_Exists then
               Put_Line ("Error: mustfile.toml not found");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               return;
            end if;

            Config := Mustfile_Loader.Load;
            begin
               Deployer.Deploy
                 (Config  => Config,
                  Target  => Must_Types.To_String (Args.Deploy_Target),
                  Tag     => Must_Types.To_String (Args.Deploy_Tag),
                  Push    => Args.Deploy_Push,
                  Dry_Run => Args.Dry_Run,
                  Verbose => Args.Verbose);
            exception
               when Deployer.Deploy_Error =>
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            end;
      end case;
   end;

exception
   when E : CLI_Parser.Parse_Error =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : Mustfile_Loader.Load_Error =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : Task_Runner.Task_Error =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : Task_Runner.Circular_Dependency =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : Mustache_Engine.Template_Error =>
      Put_Line ("Error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : Deployer.Deploy_Error =>
      Put_Line ("Deploy error: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

   when E : others =>
      Put_Line ("Unexpected error: " & Ada.Exceptions.Exception_Message (E));
      Put_Line ("Exception: " & Ada.Exceptions.Exception_Name (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);

end Must;
