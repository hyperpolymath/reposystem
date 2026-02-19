-- mustache_engine.adb
-- Mustache template engine for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

use Ada.Strings.Unbounded;

package body Mustache_Engine is

   --  Helper: lookup variable in map with String key
   function Get_Var (Variables : String_Map; Key : String) return String is
      Bounded_Key : Bounded_String;
   begin
      if Key'Length > Max_String_Length then
         return "";
      end if;
      Bounded_Key := Must_Types.To_Bounded (Key);
      if Variables.Contains (Bounded_Key) then
         return Must_Types.To_String (Variables.Element (Bounded_Key));
      else
         return "";
      end if;
   end Get_Var;

   function Has_Var (Variables : String_Map; Key : String) return Boolean is
      Bounded_Key : Bounded_String;
   begin
      if Key'Length > Max_String_Length then
         return False;
      end if;
      Bounded_Key := Must_Types.To_Bounded (Key);
      return Variables.Contains (Bounded_Key);
   end Has_Var;

   --  Read entire file content
   function Read_File (Path : String) return String is
      F       : File_Type;
      Content : Unbounded_String;
   begin
      Open (F, In_File, Path);
      while not End_Of_File (F) loop
         Append (Content, Get_Line (F));
         if not End_Of_File (F) then
            Append (Content, ASCII.LF);
         end if;
      end loop;
      Close (F);
      return Ada.Strings.Unbounded.To_String (Content);
   exception
      when Name_Error =>
         raise Template_Error with "Template file not found: " & Path;
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         raise;
   end Read_File;

   --  Write content to file
   procedure Write_File (Path : String; Content : String) is
      F : File_Type;
   begin
      --  Create parent directories if needed
      declare
         Dir : constant String := Ada.Directories.Containing_Directory (Path);
      begin
         if Dir'Length > 0 and then not Ada.Directories.Exists (Dir) then
            Ada.Directories.Create_Path (Dir);
         end if;
      end;

      Create (F, Out_File, Path);
      Put (F, Content);
      Close (F);
   exception
      when others =>
         if Is_Open (F) then
            Close (F);
         end if;
         raise;
   end Write_File;

   --  Find closing tag for section
   function Find_Section_End
     (Template : String;
      Tag_Name : String;
      Start    : Positive) return Natural
   is
      Close_Tag : constant String := "{{/" & Tag_Name & "}}";
      Open_Tag  : constant String := "{{#" & Tag_Name & "}}";
      Pos       : Natural := Start;
      Depth     : Natural := 1;
   begin
      while Pos <= Template'Last - Close_Tag'Length + 1 loop
         if Template (Pos .. Pos + Close_Tag'Length - 1) = Close_Tag then
            Depth := Depth - 1;
            if Depth = 0 then
               return Pos;
            end if;
         elsif Template (Pos .. Pos + Open_Tag'Length - 1) = Open_Tag then
            Depth := Depth + 1;
         end if;
         Pos := Pos + 1;
      end loop;
      return 0;
   end Find_Section_End;

   function Render
     (Template  : String;
      Variables : String_Map) return String
   is
      Result    : Unbounded_String;
      I         : Positive := Template'First;
      Tag_Start : Natural;
      Tag_End   : Natural;
   begin
      while I <= Template'Last loop
         --  Look for opening tag
         Tag_Start := Ada.Strings.Fixed.Index (Template (I .. Template'Last), "{{");

         if Tag_Start = 0 then
            --  No more tags, append rest of template
            Append (Result, Template (I .. Template'Last));
            exit;
         end if;

         --  Append text before tag
         if Tag_Start > I then
            Append (Result, Template (I .. Tag_Start - 1));
         end if;

         --  Find closing tag
         Tag_End := Ada.Strings.Fixed.Index
           (Template (Tag_Start .. Template'Last), "}}");

         if Tag_End = 0 then
            raise Template_Error with "Unclosed tag at position" &
              Positive'Image (Tag_Start);
         end if;

         --  Process tag
         declare
            Tag_Content : constant String :=
              Template (Tag_Start + 2 .. Tag_End - 1);
         begin
            if Tag_Content'Length = 0 then
               --  Empty tag
               null;

            elsif Tag_Content (Tag_Content'First) = '#' then
               --  Section start {{#name}}
               declare
                  Name      : constant String :=
                    Tag_Content (Tag_Content'First + 1 .. Tag_Content'Last);
                  Sec_End   : constant Natural :=
                    Find_Section_End (Template, Name, Tag_End + 2);
                  Close_Tag : constant String := "{{/" & Name & "}}";
               begin
                  if Sec_End = 0 then
                     raise Template_Error with
                       "Unclosed section: " & Name;
                  end if;

                  --  Check if variable is truthy
                  if Has_Var (Variables, Name) then
                     declare
                        Value : constant String := Get_Var (Variables, Name);
                     begin
                        if Value'Length > 0 and then Value /= "false" then
                           --  Render section content
                           Append (Result, Render
                             (Template (Tag_End + 2 .. Sec_End - 1), Variables));
                        end if;
                     end;
                  end if;

                  I := Sec_End + Close_Tag'Length;
               end;

            elsif Tag_Content (Tag_Content'First) = '^' then
               --  Inverted section {{^name}}
               declare
                  Name      : constant String :=
                    Tag_Content (Tag_Content'First + 1 .. Tag_Content'Last);
                  Sec_End   : constant Natural :=
                    Find_Section_End (Template, Name, Tag_End + 2);
                  Close_Tag : constant String := "{{/" & Name & "}}";
               begin
                  if Sec_End = 0 then
                     raise Template_Error with
                       "Unclosed inverted section: " & Name;
                  end if;

                  --  Render if variable is falsy
                  if not Has_Var (Variables, Name) or else
                     Get_Var (Variables, Name) = "" or else
                     Get_Var (Variables, Name) = "false"
                  then
                     Append (Result, Render
                       (Template (Tag_End + 2 .. Sec_End - 1), Variables));
                  end if;

                  I := Sec_End + Close_Tag'Length;
               end;

            elsif Tag_Content (Tag_Content'First) = '/' then
               --  Section end (handled above)
               I := Tag_End + 2;

            elsif Tag_Content (Tag_Content'First) = '!' then
               --  Comment {{! comment }}
               I := Tag_End + 2;

            elsif Tag_Content (Tag_Content'First) = '>' then
               --  Partial {{> partial_name}}
               declare
                  Partial_Name : constant String := Ada.Strings.Fixed.Trim
                    (Tag_Content (Tag_Content'First + 1 .. Tag_Content'Last),
                     Ada.Strings.Both);
                  Partial_Path : constant String :=
                    "templates/" & Partial_Name & ".mustache";
               begin
                  if Ada.Directories.Exists (Partial_Path) then
                     --  Load and render the partial with current variables
                     declare
                        Partial_Content : constant String :=
                          Read_File (Partial_Path);
                     begin
                        Append (Result, Render (Partial_Content, Variables));
                     end;
                  else
                     --  Partial not found - silently skip (per Mustache spec)
                     null;
                  end if;
               end;
               I := Tag_End + 2;

            elsif Tag_Content (Tag_Content'First) = '{' and then
                  Tag_Content (Tag_Content'Last) = '}'
            then
               --  Unescaped variable {{{name}}}
               declare
                  Name : constant String :=
                    Tag_Content (Tag_Content'First + 1 .. Tag_Content'Last - 1);
               begin
                  if Has_Var (Variables, Name) then
                     Append (Result, Get_Var (Variables, Name));
                  end if;
               end;
               I := Tag_End + 2;

            elsif Tag_Content (Tag_Content'First) = '&' then
               --  Unescaped variable {{&name}}
               declare
                  Name : constant String :=
                    Ada.Strings.Fixed.Trim
                      (Tag_Content (Tag_Content'First + 2 .. Tag_Content'Last),
                       Ada.Strings.Both);
               begin
                  if Has_Var (Variables, Name) then
                     Append (Result, Get_Var (Variables, Name));
                  end if;
               end;
               I := Tag_End + 2;

            else
               --  Regular variable {{name}}
               declare
                  Name : constant String := Ada.Strings.Fixed.Trim
                    (Tag_Content, Ada.Strings.Both);
               begin
                  if Has_Var (Variables, Name) then
                     --  HTML escape the value (basic escaping)
                     declare
                        Value   : constant String := Get_Var (Variables, Name);
                        Escaped : Unbounded_String;
                     begin
                        for C of Value loop
                           case C is
                              when '&' => Append (Escaped, "&amp;");
                              when '<' => Append (Escaped, "&lt;");
                              when '>' => Append (Escaped, "&gt;");
                              when '"' => Append (Escaped, "&quot;");
                              when others => Append (Escaped, C);
                           end case;
                        end loop;
                        Append (Result, Ada.Strings.Unbounded.To_String (Escaped));
                     end;
                  end if;
               end;
               I := Tag_End + 2;
            end if;
         end;
      end loop;

      return Ada.Strings.Unbounded.To_String (Result);
   end Render;

   function Render_File
     (Template_Path : String;
      Variables     : String_Map) return String
   is
      Content : constant String := Read_File (Template_Path);
   begin
      return Render (Content, Variables);
   end Render_File;

   --  Render destination path with variables
   function Render_Path
     (Path      : String;
      Variables : String_Map) return String
   is
   begin
      return Render (Path, Variables);
   end Render_Path;

   procedure Apply_Template
     (Source      : String;
      Destination : String;
      Variables   : String_Map;
      Dry_Run     : Boolean := False;
      Verbose     : Boolean := False)
   is
      Rendered_Dest : constant String := Render_Path (Destination, Variables);
      Content       : constant String := Render_File (Source, Variables);
   begin
      if Verbose or Dry_Run then
         Put_Line ("  " & Source & " -> " & Rendered_Dest);
      end if;

      if not Dry_Run then
         Write_File (Rendered_Dest, Content);
      end if;
   end Apply_Template;

   procedure Apply_All
     (Config  : Mustfile_Config;
      Dry_Run : Boolean := False;
      Verbose : Boolean := False)
   is
      Variables : constant String_Map := Config.Variables;
   begin
      if Config.Templates.Is_Empty then
         Put_Line ("No templates defined");
         return;
      end if;

      Put_Line ("Applying templates:");

      for T of Config.Templates loop
         Apply_Template
           (Source      => Must_Types.To_Path_String (T.Source),
            Destination => Must_Types.To_Path_String (T.Destination),
            Variables   => Variables,
            Dry_Run     => Dry_Run,
            Verbose     => Verbose);
      end loop;

      if Dry_Run then
         Put_Line ("(dry run - no files written)");
      else
         Put_Line ("Done.");
      end if;
   end Apply_All;

   procedure Apply_Named
     (Config        : Mustfile_Config;
      Template_Name : String;
      Variables     : String_Map;
      Dry_Run       : Boolean := False;
      Verbose       : Boolean := False)
   is
      Merged_Vars : String_Map := Config.Variables;
   begin
      --  Merge provided variables with config variables
      for C in Variables.Iterate loop
         Merged_Vars.Include (String_Maps.Key (C), String_Maps.Element (C));
      end loop;

      --  Find and apply template
      for T of Config.Templates loop
         if Must_Types.To_String (T.Name) = Template_Name then
            Put_Line ("Applying template: " & Template_Name);
            Apply_Template
              (Source      => Must_Types.To_Path_String (T.Source),
               Destination => Must_Types.To_Path_String (T.Destination),
               Variables   => Merged_Vars,
               Dry_Run     => Dry_Run,
               Verbose     => Verbose);

            if Dry_Run then
               Put_Line ("(dry run - no files written)");
            else
               Put_Line ("Done.");
            end if;
            return;
         end if;
      end loop;

      raise Template_Error with "Template not found: " & Template_Name;
   end Apply_Named;

   procedure List_Templates (Config : Mustfile_Config) is
      Max_Len : Natural := 0;
   begin
      if Config.Templates.Is_Empty then
         Put_Line ("No templates defined in mustfile.toml");
         return;
      end if;

      --  Find max name length
      for T of Config.Templates loop
         if Must_Types.Bounded_Strings.Length (T.Name) > Max_Len then
            Max_Len := Must_Types.Bounded_Strings.Length (T.Name);
         end if;
      end loop;

      Put_Line ("Available templates:");
      Put_Line ("");

      for T of Config.Templates loop
         declare
            Name    : constant String := Must_Types.To_String (T.Name);
            Desc    : constant String := Must_Types.To_Description_String (T.Description);
            Padding : constant String (1 .. Max_Len - Name'Length + 2) :=
              [others => ' '];
         begin
            if Desc'Length > 0 then
               Put_Line ("  " & Name & Padding & "# " & Desc);
            else
               Put_Line ("  " & Name);
            end if;
         end;
      end loop;
   end List_Templates;

   function Template_Exists
     (Config        : Mustfile_Config;
      Template_Name : String) return Boolean
   is
   begin
      for T of Config.Templates loop
         if Must_Types.To_String (T.Name) = Template_Name then
            return True;
         end if;
      end loop;
      return False;
   end Template_Exists;

end Mustache_Engine;
