-- must_types.ads
-- Common type definitions for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Containers.Vectors;
with Ada.Containers.Ordered_Maps;
with Ada.Strings.Bounded;

package Must_Types is
   pragma Elaborate_Body;

   --  SPARK-compatible bounded strings with reasonable max lengths
   --  These limits are chosen to balance memory usage with practical needs
   Max_Path_Length        : constant := 4096;  -- Maximum path length
   Max_String_Length      : constant := 1024;  -- General string max
   Max_Command_Length     : constant := 8192;  -- Command lines can be long
   Max_Description_Length : constant := 2048;  -- Descriptions

   package Bounded_Paths is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Path_Length);
   subtype Bounded_Path is Bounded_Paths.Bounded_String;
   use type Bounded_Path;  -- Make = and < visible

   package Bounded_Strings is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_String_Length);
   subtype Bounded_String is Bounded_Strings.Bounded_String;
   use type Bounded_String;  -- Make = and < visible

   package Bounded_Commands is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Command_Length);
   subtype Bounded_Command is Bounded_Commands.Bounded_String;
   use type Bounded_Command;  -- Make = and < visible

   package Bounded_Descriptions is new Ada.Strings.Bounded.Generic_Bounded_Length
     (Max => Max_Description_Length);
   subtype Bounded_Description is Bounded_Descriptions.Bounded_String;
   use type Bounded_Description;  -- Make = and < visible

   --  Standard containers with bounded strings for safety
   --  Note: When SPARK tools are available, these can be verified
   --  String vector type (using bounded strings)
   package String_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Bounded_String);

   subtype String_Vector is String_Vectors.Vector;

   --  Command vector type (commands can be longer)
   package Command_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Bounded_Command);

   subtype Command_Vector is Command_Vectors.Vector;

   --  Path vector type
   package Path_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Bounded_Path);

   subtype Path_Vector is Path_Vectors.Vector;

   --  Task definition with SPARK contracts
   type Task_Def is record
      Name         : Bounded_String;
      Description  : Bounded_Description;
      Commands     : Command_Vector;
      Dependencies : String_Vector;
      Script       : Bounded_Command;
      Working_Dir  : Bounded_Path;
   end record with
      Predicate => Bounded_Strings.Length (Task_Def.Name) > 0;
      --  Task must have a non-empty name

   --  Task vector
   package Task_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Task_Def);

   subtype Task_Vector is Task_Vectors.Vector;

   --  Requirement kind
   type Requirement_Kind is (Must_Have, Must_Not_Have, Must_Contain) with
      Default_Value => Must_Have;

   --  Requirement definition with SPARK contracts
   type Requirement_Def is record
      Kind    : Requirement_Kind;
      Path    : Bounded_Path;
      Pattern : Bounded_String;  --  For Must_Contain
   end record with
      Predicate => Bounded_Paths.Length (Requirement_Def.Path) > 0;
      --  Requirement must have a non-empty path

   --  Requirement vector
   package Requirement_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Requirement_Def);

   subtype Requirement_Vector is Requirement_Vectors.Vector;

   --  Template definition with SPARK contracts
   type Template_Def is record
      Name        : Bounded_String;
      Source      : Bounded_Path;
      Destination : Bounded_Path;
      Description : Bounded_Description;
   end record with
      Predicate => Bounded_Strings.Length (Template_Def.Name) > 0 and then
                   Bounded_Paths.Length (Template_Def.Source) > 0 and then
                   Bounded_Paths.Length (Template_Def.Destination) > 0;
      --  Template must have non-empty name, source, and destination

   --  Template vector
   package Template_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Template_Def);

   subtype Template_Vector is Template_Vectors.Vector;

   --  Project configuration with SPARK contracts
   type Project_Config is record
      Name         : Bounded_String;
      Version      : Bounded_String;
      License      : Bounded_String;
      Author       : Bounded_String;
   end record with
      Predicate => Bounded_Strings.Length (Project_Config.Name) > 0 and then
                   Bounded_Strings.Length (Project_Config.Version) > 0;
      --  Project must have non-empty name and version

   --  Enforcement configuration with SPARK contracts
   type Enforcement_Config is record
      License               : Bounded_String;
      Copyright_Holder      : Bounded_String;
      Podman_Not_Docker     : Boolean := True;
      Gitlab_Not_Github     : Boolean := True;
      No_Trailing_Whitespace : Boolean := True;
      No_Tabs               : Boolean := True;
      Unix_Line_Endings     : Boolean := True;
      Max_Line_Length       : Natural := 100;
   end record with
      Predicate => Enforcement_Config.Max_Line_Length > 0 and then
                   Enforcement_Config.Max_Line_Length <= 500;
      --  Line length must be reasonable (1-500)

   --  String-to-String map type (for variables)
   package String_Maps is new Ada.Containers.Ordered_Maps
     (Key_Type     => Bounded_String,
      Element_Type => Bounded_String);

   subtype String_Map is String_Maps.Map;

   --  Full mustfile configuration with SPARK contracts
   type Mustfile_Config is record
      Project      : Project_Config;
      Tasks        : Task_Vector;
      Variables    : String_Map;
      Requirements : Requirement_Vector;
      Templates    : Template_Vector;
      Enforcement  : Enforcement_Config;
   end record;
      --  Config validation happens at load time in mustfile_loader

   --  Helper functions for bounded string conversion
   function To_String (S : Bounded_String) return String is
     (Bounded_Strings.To_String (S)) with
      Post => To_String'Result'Length <= Max_String_Length;

   function To_Bounded (S : String) return Bounded_String is
     (Bounded_Strings.To_Bounded_String (S)) with
      Pre  => S'Length <= Max_String_Length,
      Post => Bounded_Strings.To_String (To_Bounded'Result) = S;

   function To_Path_String (S : Bounded_Path) return String is
     (Bounded_Paths.To_String (S)) with
      Post => To_Path_String'Result'Length <= Max_Path_Length;

   function To_Bounded_Path (S : String) return Bounded_Path is
     (Bounded_Paths.To_Bounded_String (S)) with
      Pre  => S'Length <= Max_Path_Length,
      Post => Bounded_Paths.To_String (To_Bounded_Path'Result) = S;

   function To_Command_String (S : Bounded_Command) return String is
     (Bounded_Commands.To_String (S)) with
      Post => To_Command_String'Result'Length <= Max_Command_Length;

   function To_Bounded_Command (S : String) return Bounded_Command is
     (Bounded_Commands.To_Bounded_String (S)) with
      Pre  => S'Length <= Max_Command_Length,
      Post => Bounded_Commands.To_String (To_Bounded_Command'Result) = S;

   function To_Description_String (S : Bounded_Description) return String is
     (Bounded_Descriptions.To_String (S)) with
      Post => To_Description_String'Result'Length <= Max_Description_Length;

   function To_Bounded_Description (S : String) return Bounded_Description is
     (Bounded_Descriptions.To_Bounded_String (S)) with
      Pre  => S'Length <= Max_Description_Length,
      Post => Bounded_Descriptions.To_String (To_Bounded_Description'Result) = S;

end Must_Types;
