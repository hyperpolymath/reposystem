-- toml_parser.ads
-- TOML parser for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Must_Types; use Must_Types;

package TOML_Parser is

   --  TOML value types
   type Value_Kind is
     (Val_String,
      Val_Integer,
      Val_Float,
      Val_Boolean,
      Val_Array,
      Val_Table);

   type TOML_Value;
   type TOML_Value_Access is access all TOML_Value;

   --  Forward declarations for containers
   package Value_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => TOML_Value_Access);

   package Value_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type     => String,
      Element_Type => TOML_Value_Access);

   --  TOML value type (discriminated record)
   type TOML_Value (Kind : Value_Kind := Val_String) is record
      case Kind is
         when Val_String =>
            Str_Val : Unbounded_String;
         when Val_Integer =>
            Int_Val : Long_Integer;
         when Val_Float =>
            Float_Val : Long_Float;
         when Val_Boolean =>
            Bool_Val : Boolean;
         when Val_Array =>
            Arr_Val : Value_Vectors.Vector;
         when Val_Table =>
            Table_Val : Value_Maps.Map;
      end case;
   end record;

   --  Root TOML document (table)
   type TOML_Document is new Value_Maps.Map with null record;

   --  Parse a TOML file
   function Parse_File (Filename : String) return TOML_Document;

   --  Parse a TOML string
   function Parse_String (Content : String) return TOML_Document;

   --  Get a value by path (e.g., "project.name")
   function Get (Doc : TOML_Document; Path : String)
     return TOML_Value_Access;

   --  Get string value
   function Get_String (Doc : TOML_Document; Path : String;
                        Default : String := "") return String;

   --  Get boolean value
   function Get_Boolean (Doc : TOML_Document; Path : String;
                         Default : Boolean := False) return Boolean;

   --  Get integer value
   function Get_Integer (Doc : TOML_Document; Path : String;
                         Default : Long_Integer := 0) return Long_Integer;

   --  Get string array
   function Get_String_Array (Doc : TOML_Document; Path : String)
     return String_Vector;

   --  Check if path exists
   function Has (Doc : TOML_Document; Path : String) return Boolean;

   --  Get table keys at path
   function Get_Table_Keys (Doc : TOML_Document; Path : String)
     return String_Vector;

   --  Parse error exception
   Parse_Error : exception;

   --  Helper: create string value
   function Make_String (S : String) return TOML_Value_Access;

   --  Helper: create boolean value
   function Make_Boolean (B : Boolean) return TOML_Value_Access;

   --  Helper: create integer value
   function Make_Integer (I : Long_Integer) return TOML_Value_Access;

   --  Helper: create empty table
   function Make_Table return TOML_Value_Access;

   --  Helper: create empty array
   function Make_Array return TOML_Value_Access;

end TOML_Parser;
