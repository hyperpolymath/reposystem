-- SPDX-License-Identifier: PMPL-1.0
-- Progress bar implementation

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Calendar; use Ada.Calendar;

package body Progress is

   function Create
     (Total : Natural;
      Label : String := "";
      Style : Bar_Style := Classic;
      Width : Positive := 40) return Progress_Bar
   is
      Bar : Progress_Bar;
   begin
      Bar.Total := Total;
      Bar.Current := 0;
      Bar.Width := Width;
      Bar.Style := Style;
      Bar.Label := To_Unbounded_String (Label);
      Bar.Show_Percent := True;
      return Bar;
   end Create;

   procedure Update (Bar : in Out Progress_Bar; Current : Natural) is
   begin
      Bar.Current := Natural'Min (Current, Bar.Total);
   end Update;

   procedure Increment (Bar : in Out Progress_Bar; Amount : Natural := 1) is
   begin
      Bar.Current := Natural'Min (Bar.Current + Amount, Bar.Total);
   end Increment;

   procedure Clear_Line is
   begin
      Put (ASCII.CR);
      Put ((1 .. 80 => ' '));
      Put (ASCII.CR);
   end Clear_Line;

   procedure Display (Bar : Progress_Bar) is
      Percent : Natural;
      Filled : Natural;
      Empty : Natural;
      Fill_Char : Character;
      Empty_Char : Character;
   begin
      if Bar.Total = 0 then
         Percent := 100;
      else
         Percent := (Bar.Current * 100) / Bar.Total;
      end if;

      Filled := (Bar.Current * Bar.Width) / (if Bar.Total = 0 then 1 else Bar.Total);
      Empty := Bar.Width - Filled;

      -- Select characters based on style
      case Bar.Style is
         when Classic =>
            Fill_Char := '#';
            Empty_Char := '.';
         when Block =>
            Fill_Char := '#';  -- Would be █ but using ASCII
            Empty_Char := '.'; -- Would be ░
         when Arrow =>
            Fill_Char := '=';
            Empty_Char := ' ';
         when Dots =>
            Fill_Char := '*';
            Empty_Char := 'o';
         when Minimal =>
            Fill_Char := '=';
            Empty_Char := '-';
      end case;

      Clear_Line;

      -- Print label if present
      if Length (Bar.Label) > 0 then
         Put (To_String (Bar.Label) & " ");
      end if;

      -- Print bar
      Put ("[");
      Put ((1 .. Filled => Fill_Char));

      -- Arrow head for Arrow style
      if Bar.Style = Arrow and Filled < Bar.Width then
         Put (">");
         Put ((1 .. Empty - 1 => Empty_Char));
      else
         Put ((1 .. Empty => Empty_Char));
      end if;

      Put ("]");

      -- Print percentage
      if Bar.Show_Percent then
         Put (" " & Natural'Image (Percent) & "%");
      end if;

      Flush;
   end Display;

   procedure Display_With_Message (Bar : Progress_Bar; Message : String) is
   begin
      Display (Bar);
      Put (" " & Message);
      Flush;
   end Display_With_Message;

   procedure Complete (Bar : in Out Progress_Bar; Message : String := "Done") is
   begin
      Bar.Current := Bar.Total;
      Display (Bar);
      Put_Line (" " & Message);
   end Complete;

   procedure Fail (Bar : in Out Progress_Bar; Message : String := "Failed") is
   begin
      Clear_Line;
      if Length (Bar.Label) > 0 then
         Put (To_String (Bar.Label) & " ");
      end if;
      Put_Line ("[FAILED] " & Message);
   end Fail;

   -- Spinner implementation
   Spinner_Frames_Dots : constant array (0 .. 3) of Character := ('.', 'o', 'O', 'o');
   Spinner_Frames_Line : constant array (0 .. 3) of Character := ('-', '\', '|', '/');

   procedure Start_Spinner (Label : String := ""; Style : Spinner_Style := Dots) is
   begin
      Spinner_Active := True;
      Spinner_Frame := 0;
      Spinner_Label := To_Unbounded_String (Label);
   end Start_Spinner;

   procedure Stop_Spinner (Message : String := "Done") is
   begin
      Spinner_Active := False;
      Clear_Line;
      if Length (Spinner_Label) > 0 then
         Put (To_String (Spinner_Label) & " ");
      end if;
      Put_Line (Message);
   end Stop_Spinner;

   procedure Tick_Spinner is
      Frame_Char : Character;
   begin
      if not Spinner_Active then
         return;
      end if;

      Frame_Char := Spinner_Frames_Line (Spinner_Frame mod 4);
      Spinner_Frame := Spinner_Frame + 1;

      Clear_Line;
      if Length (Spinner_Label) > 0 then
         Put (To_String (Spinner_Label) & " ");
      end if;
      Put (Frame_Char);
      Flush;
   end Tick_Spinner;

   function Format_Duration (Seconds : Duration) return String is
      Total_Secs : constant Natural := Natural (Seconds);
      Hours : constant Natural := Total_Secs / 3600;
      Mins : constant Natural := (Total_Secs mod 3600) / 60;
      Secs : constant Natural := Total_Secs mod 60;
   begin
      if Hours > 0 then
         return Natural'Image (Hours) & "h" &
                Natural'Image (Mins) & "m" &
                Natural'Image (Secs) & "s";
      elsif Mins > 0 then
         return Natural'Image (Mins) & "m" &
                Natural'Image (Secs) & "s";
      else
         return Natural'Image (Secs) & "s";
      end if;
   end Format_Duration;

   function Format_Bytes (Bytes : Natural) return String is
   begin
      if Bytes >= 1_073_741_824 then
         return Natural'Image (Bytes / 1_073_741_824) & " GB";
      elsif Bytes >= 1_048_576 then
         return Natural'Image (Bytes / 1_048_576) & " MB";
      elsif Bytes >= 1024 then
         return Natural'Image (Bytes / 1024) & " KB";
      else
         return Natural'Image (Bytes) & " B";
      end if;
   end Format_Bytes;

end Progress;
