-- SPDX-License-Identifier: PMPL-1.0
-- Progress - Progress bar display for CLI operations
-- Provides visual feedback for long-running operations

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Progress is

   -- Progress bar styles
   type Bar_Style is (
      Classic,      -- [####....] 50%
      Block,        -- [█████░░░░░] 50%
      Arrow,        -- [====>    ] 50%
      Dots,         -- [●●●●○○○○] 50%
      Minimal       -- 50% ━━━━━━━━━━
   );

   type Progress_Bar is record
      Total        : Natural := 100;
      Current      : Natural := 0;
      Width        : Positive := 40;
      Style        : Bar_Style := Classic;
      Label        : Unbounded_String := Null_Unbounded_String;
      Show_Percent : Boolean := True;
      Show_ETA     : Boolean := False;
      Start_Time   : Duration := 0.0;
   end record;

   -- Create and configure
   function Create
     (Total : Natural;
      Label : String := "";
      Style : Bar_Style := Classic;
      Width : Positive := 40) return Progress_Bar;

   -- Update progress
   procedure Update (Bar : in out Progress_Bar; Current : Natural);
   procedure Increment (Bar : in Out Progress_Bar; Amount : Natural := 1);

   -- Display (writes to stdout, overwrites current line)
   procedure Display (Bar : Progress_Bar);
   procedure Display_With_Message (Bar : Progress_Bar; Message : String);

   -- Complete (finalizes the bar)
   procedure Complete (Bar : in Out Progress_Bar; Message : String := "Done");
   procedure Fail (Bar : in Out Progress_Bar; Message : String := "Failed");

   -- Spinner for indeterminate progress
   type Spinner_Style is (Dots, Line, Circle, Braille);

   procedure Start_Spinner (Label : String := ""; Style : Spinner_Style := Dots);
   procedure Stop_Spinner (Message : String := "Done");
   procedure Tick_Spinner;  -- Call in loop to animate

   -- Utility
   procedure Clear_Line;
   function Format_Duration (Seconds : Duration) return String;
   function Format_Bytes (Bytes : Natural) return String;

private
   Spinner_Frame : Natural := 0;
   Spinner_Active : Boolean := False;
   Spinner_Label : Unbounded_String := Null_Unbounded_String;

end Progress;
