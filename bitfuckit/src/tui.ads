-- SPDX-License-Identifier: PMPL-1.0
-- TUI package for bitfuckit - Terminal User Interface in Ada/SPARK
-- Provides interactive menu-driven interface

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package TUI
   with SPARK_Mode => On
is
   -- Terminal colors
   type Color is (Default, Red, Green, Yellow, Blue, Magenta, Cyan, White);

   -- Menu item
   type Menu_Item is record
      Key         : Character;
      Label       : Unbounded_String;
      Description : Unbounded_String;
   end record;

   type Menu_Items is array (Positive range <>) of Menu_Item;

   -- Screen operations
   procedure Clear_Screen
      with Global => null;

   procedure Move_Cursor (Row, Col : Positive)
      with Global => null;

   procedure Set_Color (Fg : Color; Bold : Boolean := False)
      with Global => null;

   procedure Reset_Color
      with Global => null;

   -- Output with colors
   procedure Put_Colored (Text : String; Fg : Color; Bold : Boolean := False);
   procedure Put_Line_Colored (Text : String; Fg : Color; Bold : Boolean := False);

   -- UI Components
   procedure Draw_Header (Title : String);
   procedure Draw_Footer (Status : String);
   procedure Draw_Box (Row, Col, Width, Height : Positive; Title : String := "");
   procedure Draw_Menu (Items : Menu_Items; Selected : Positive);
   procedure Draw_Progress (Current, Total : Natural; Label : String);

   -- Input
   function Get_Key return Character;
   function Get_Line_Input (Prompt : String) return Unbounded_String;
   function Confirm (Prompt : String) return Boolean;

   -- Main TUI loop
   procedure Run_TUI;

   -- Troubleshooter
   procedure Show_Troubleshooter;

   -- Help screens
   procedure Show_Help (Topic : String := "");

end TUI;
