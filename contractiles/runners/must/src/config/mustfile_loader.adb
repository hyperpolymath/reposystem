-- mustfile_loader.adb
-- Mustfile configuration loader for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Directories;
with Ada.Text_IO; use Ada.Text_IO;
with TOML_Parser; use TOML_Parser;

package body Mustfile_Loader is

   function Mustfile_Exists return Boolean is
   begin
      return Ada.Directories.Exists (Mustfile_Name);
   end Mustfile_Exists;

   function Load return Mustfile_Config is
   begin
      return Load (Mustfile_Name);
   end Load;

   function Load (Path : String) return Mustfile_Config is
      Doc    : TOML_Document;
      Config : Mustfile_Config;
   begin
      Doc := Parse_File (Path);

      --  Load project section
      Config.Project.Name := Must_Types.To_Bounded (Get_String (Doc, "project.name", ""));
      Config.Project.Version := Must_Types.To_Bounded (Get_String (Doc, "project.version", ""));
      Config.Project.License := Must_Types.To_Bounded (Get_String (Doc, "project.license", ""));
      Config.Project.Author := Must_Types.To_Bounded (Get_String (Doc, "project.author", ""));

      --  Load tasks section
      declare
         Task_Keys : constant String_Vector := Get_Table_Keys (Doc, "tasks");
      begin
         for Key of Task_Keys loop
            declare
               Task_Path   : constant String := "tasks." & Must_Types.To_String (Key);
               T           : Task_Def;
               Cmd_Strings : constant String_Vector :=
                 Get_String_Array (Doc, Task_Path & ".commands");
            begin
               T.Name := Key;  -- Already Bounded_String
               T.Description := Must_Types.To_Bounded_Description
                 (Get_String (Doc, Task_Path & ".description", ""));

               --  Convert String_Vector to Command_Vector
               for Cmd of Cmd_Strings loop
                  T.Commands.Append
                    (Must_Types.To_Bounded_Command (Must_Types.To_String (Cmd)));
               end loop;

               T.Dependencies := Get_String_Array (Doc, Task_Path & ".dependencies");
               T.Script := Must_Types.To_Bounded_Command
                 (Get_String (Doc, Task_Path & ".script", ""));
               T.Working_Dir := Must_Types.To_Bounded_Path
                 (Get_String (Doc, Task_Path & ".working_dir", ""));
               Config.Tasks.Append (T);
            end;
         end loop;
      end;

      --  Load variables section
      declare
         Var_Keys : constant String_Vector := Get_Table_Keys (Doc, "variables");
      begin
         for Key of Var_Keys loop
            declare
               Key_Str : constant String := Must_Types.To_String (Key);
               Val_Str : constant String := Get_String (Doc, "variables." & Key_Str, "");
            begin
               Config.Variables.Insert
                 (Key, Must_Types.To_Bounded (Val_Str));
            end;
         end loop;
      end;

      --  Load requirements section
      declare
         Must_Have : constant String_Vector :=
           Get_String_Array (Doc, "requirements.must_have");
         Must_Not_Have : constant String_Vector :=
           Get_String_Array (Doc, "requirements.must_not_have");
      begin
         for Path of Must_Have loop
            declare
               Path_Str : constant String := Must_Types.To_String (Path);
            begin
               if Path_Str'Length <= Max_Path_Length then
                  Config.Requirements.Append
                    (Must_Types.Requirement_Def'
                       (Kind    => Must_Types.Must_Have,
                        Path    => Must_Types.To_Bounded_Path (Path_Str),
                        Pattern => Must_Types.To_Bounded ("")));
               end if;
            end;
         end loop;

         for Path of Must_Not_Have loop
            declare
               Path_Str : constant String := Must_Types.To_String (Path);
            begin
               if Path_Str'Length <= Max_Path_Length then
                  Config.Requirements.Append
                    (Must_Types.Requirement_Def'
                       (Kind    => Must_Types.Must_Not_Have,
                        Path    => Must_Types.To_Bounded_Path (Path_Str),
                        Pattern => Must_Types.To_Bounded ("")));
               end if;
            end;
         end loop;

         --  TODO: Re-add requirements.content support when Requirements_Content
         --  field is added back to Mustfile_Config
         --  For now, content requirements must be added as static Requirement_Def records
      end;

      --  Load templates section
      declare
         Template_Keys : constant String_Vector := Get_Table_Keys (Doc, "templates");
      begin
         for Key of Template_Keys loop
            declare
               Tpl_Path : constant String := "templates." & Must_Types.To_String (Key);
               T        : Template_Def;
            begin
               T.Name := Key;  -- Already Bounded_String
               T.Source := Must_Types.To_Bounded_Path
                 (Get_String (Doc, Tpl_Path & ".source", ""));
               T.Destination := Must_Types.To_Bounded_Path
                 (Get_String (Doc, Tpl_Path & ".destination", ""));
               T.Description := Must_Types.To_Bounded_Description
                 (Get_String (Doc, Tpl_Path & ".description", ""));
               Config.Templates.Append (T);
            end;
         end loop;
      end;

      --  Load enforcement section
      Config.Enforcement.License := Must_Types.To_Bounded
        (Get_String (Doc, "enforcement.license", ""));
      Config.Enforcement.Copyright_Holder := Must_Types.To_Bounded
        (Get_String (Doc, "enforcement.copyright_holder", ""));
      Config.Enforcement.Podman_Not_Docker :=
        Get_Boolean (Doc, "enforcement.podman_not_docker", True);
      Config.Enforcement.Gitlab_Not_Github :=
        Get_Boolean (Doc, "enforcement.gitlab_not_github", True);
      Config.Enforcement.No_Trailing_Whitespace :=
        Get_Boolean (Doc, "enforcement.checks.no_trailing_whitespace", True);
      Config.Enforcement.No_Tabs :=
        Get_Boolean (Doc, "enforcement.checks.no_tabs", True);
      Config.Enforcement.Unix_Line_Endings :=
        Get_Boolean (Doc, "enforcement.checks.unix_line_endings", True);
      Config.Enforcement.Max_Line_Length := Natural
        (Get_Integer (Doc, "enforcement.checks.max_line_length", 100));

      return Config;
   exception
      when TOML_Parser.Parse_Error =>
         raise Load_Error with "Failed to parse mustfile: " & Path;
   end Load;

   procedure Create_Default_Mustfile is
   begin
      Create_Default_Mustfile (Mustfile_Name);
   end Create_Default_Mustfile;

   procedure Create_Default_Mustfile (Path : String) is
      F : File_Type;
   begin
      Create (F, Out_File, Path);
      Put_Line (F, "# mustfile.toml");
      Put_Line (F, "# Configuration for Must - task runner + template engine + enforcer");
      Put_Line (F, "# https://gitlab.com/hyperpolymath/must");
      Put_Line (F, "");
      Put_Line (F, "[project]");
      Put_Line (F, "name = ""my-project""");
      Put_Line (F, "version = ""0.1.0""");
      Put_Line (F, "license = ""AGPL-3.0-or-later""");
      Put_Line (F, "author = ""Your Name""");
      Put_Line (F, "");
      Put_Line (F, "# Variables available in tasks and templates");
      Put_Line (F, "[variables]");
      Put_Line (F, "# server = ""production.example.com""");
      Put_Line (F, "");
      Put_Line (F, "# Task definitions");
      Put_Line (F, "[tasks]");
      Put_Line (F, "");
      Put_Line (F, "[tasks.build]");
      Put_Line (F, "description = ""Build the project""");
      Put_Line (F, "commands = [""echo 'Building...'""]");
      Put_Line (F, "");
      Put_Line (F, "[tasks.test]");
      Put_Line (F, "description = ""Run tests""");
      Put_Line (F, "dependencies = [""build""]");
      Put_Line (F, "commands = [""echo 'Testing...'""]");
      Put_Line (F, "");
      Put_Line (F, "[tasks.clean]");
      Put_Line (F, "description = ""Clean build artifacts""");
      Put_Line (F, "commands = [""rm -rf bin/ obj/""]");
      Put_Line (F, "");
      Put_Line (F, "# Requirements enforcement");
      Put_Line (F, "[requirements]");
      Put_Line (F, "must_have = [");
      Put_Line (F, "    ""LICENSE"",");
      Put_Line (F, "    ""README.md"",");
      Put_Line (F, "]");
      Put_Line (F, "");
      Put_Line (F, "must_not_have = [");
      Put_Line (F, "    ""Makefile"",");
      Put_Line (F, "    ""Dockerfile"",");
      Put_Line (F, "]");
      Put_Line (F, "");
      Put_Line (F, "# Templates");
      Put_Line (F, "[templates]");
      Put_Line (F, "");
      Put_Line (F, "# [templates.ada_package]");
      Put_Line (F, "# source = ""templates/ada/package.ads.mustache""");
      Put_Line (F, "# destination = ""src/{{module_name}}.ads""");
      Put_Line (F, "# description = ""Generate Ada package specification""");
      Put_Line (F, "");
      Put_Line (F, "# Enforcement rules");
      Put_Line (F, "[enforcement]");
      Put_Line (F, "license = ""AGPL-3.0-or-later""");
      Put_Line (F, "copyright_holder = ""Your Name""");
      Put_Line (F, "podman_not_docker = true");
      Put_Line (F, "gitlab_not_github = true");
      Put_Line (F, "");
      Put_Line (F, "[enforcement.checks]");
      Put_Line (F, "no_trailing_whitespace = true");
      Put_Line (F, "no_tabs = true");
      Put_Line (F, "unix_line_endings = true");
      Put_Line (F, "max_line_length = 100");
      Close (F);

      Put_Line ("Created " & Path);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         raise;
   end Create_Default_Mustfile;

end Mustfile_Loader;
