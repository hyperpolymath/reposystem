-- must_types.ads
-- Common type definitions for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: PMPL-1.0-or-later

pragma Ada_2022;

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Must_Types is

   --  String vector type
   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   subtype String_Vector is String_Vectors.Vector;

   --  String-to-String map type
   package String_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type     => String,
      Element_Type => String);

   subtype String_Map is String_Maps.Map;

   --  Unbounded string vector
   package Unbounded_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Unbounded_String);

   subtype Unbounded_Vector is Unbounded_Vectors.Vector;

   --  Task definition
   type Task_Def is record
      Name         : Unbounded_String;
      Description  : Unbounded_String;
      Commands     : String_Vector;
      Dependencies : String_Vector;
      Script       : Unbounded_String;
      Working_Dir  : Unbounded_String;
   end record;

   --  Task vector
   package Task_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Task_Def);

   subtype Task_Vector is Task_Vectors.Vector;

   --  Requirement kind
   type Requirement_Kind is (Must_Have, Must_Not_Have, Must_Contain);

   --  Requirement definition
   type Requirement_Def is record
      Kind    : Requirement_Kind;
      Path    : Unbounded_String;
      Pattern : Unbounded_String;  --  For Must_Contain
   end record;

   --  Requirement vector
   package Requirement_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Requirement_Def);

   subtype Requirement_Vector is Requirement_Vectors.Vector;

   --  Template definition
   type Template_Def is record
      Name        : Unbounded_String;
      Source      : Unbounded_String;
      Destination : Unbounded_String;
      Description : Unbounded_String;
   end record;

   --  Template vector
   package Template_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => Template_Def);

   subtype Template_Vector is Template_Vectors.Vector;

   --  Project configuration
   type Project_Config is record
      Name         : Unbounded_String;
      Version      : Unbounded_String;
      License      : Unbounded_String;
      Author       : Unbounded_String;
   end record;

   --  Enforcement configuration
   type Enforcement_Config is record
      License               : Unbounded_String;
      Copyright_Holder      : Unbounded_String;
      Podman_Not_Docker     : Boolean := True;
      Gitlab_Not_Github     : Boolean := True;
      No_Trailing_Whitespace : Boolean := True;
      No_Tabs               : Boolean := True;
      Unix_Line_Endings     : Boolean := True;
      Max_Line_Length       : Natural := 100;
   end record;

   --  Full mustfile configuration
   type Mustfile_Config is record
      Project      : Project_Config;
      Tasks        : Task_Vector;
      Variables    : String_Map;
      Requirements : Requirement_Vector;
      Templates    : Template_Vector;
      Enforcement  : Enforcement_Config;
   end record;

   --  Helper functions
   function To_String (S : Unbounded_String) return String
     renames Ada.Strings.Unbounded.To_String;

   function To_Unbounded (S : String) return Unbounded_String
     renames Ada.Strings.Unbounded.To_Unbounded_String;

end Must_Types;
