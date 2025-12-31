-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
--
-- reposystem_tui.adb - Main TUI package body

pragma SPARK_Mode (On);

with Ada.Text_IO;

package body Reposystem_TUI is

   --  Initialize application state
   function Initialize (Width : Screen_Width; Height : Screen_Height)
     return App_State
   is
   begin
      return (Width      => Width,
              Height     => Height,
              Cursor_X   => 1,
              Cursor_Y   => 1,
              Mode       => Graph_View,
              Filter     => All_Aspects,
              Repo_Count => 0,
              Edge_Count => 0,
              Selected   => 0,
              Running    => True);
   end Initialize;

   --  Process user input
   procedure Handle_Input (State : in Out App_State; Key : Character) is
   begin
      case Key is
         when 'q' | 'Q' =>
            State.Running := False;

         when 'h' | Character'Val (68) =>  --  Left arrow
            if State.Cursor_X > 1 then
               State.Cursor_X := State.Cursor_X - 1;
            end if;

         when 'l' | Character'Val (67) =>  --  Right arrow
            if State.Cursor_X < State.Width then
               State.Cursor_X := State.Cursor_X + 1;
            end if;

         when 'k' | Character'Val (65) =>  --  Up arrow
            if State.Cursor_Y > 1 then
               State.Cursor_Y := State.Cursor_Y - 1;
            end if;

         when 'j' | Character'Val (66) =>  --  Down arrow
            if State.Cursor_Y < State.Height then
               State.Cursor_Y := State.Cursor_Y + 1;
            end if;

         when '1' =>
            State.Mode := Graph_View;

         when '2' =>
            State.Mode := List_View;

         when '3' =>
            State.Mode := Detail_View;

         when '4' =>
            State.Mode := Scenario_View;

         when 'a' =>
            State.Filter := All_Aspects;

         when 's' =>
            State.Filter := Security;

         when 'r' =>
            State.Filter := Reliability;

         when 'p' =>
            State.Filter := Performance;

         when 'n' =>  --  Next selection
            if State.Selected < State.Repo_Count then
               State.Selected := State.Selected + 1;
            end if;

         when 'N' =>  --  Previous selection
            if State.Selected > 0 then
               State.Selected := State.Selected - 1;
            end if;

         when others =>
            null;  --  Ignore unknown keys
      end case;
   end Handle_Input;

   --  Render current view
   procedure Render (State : App_State) is
      pragma SPARK_Mode (Off);  --  I/O operations not in SPARK
   begin
      --  Clear screen
      Ada.Text_IO.Put (ASCII.ESC & "[2J" & ASCII.ESC & "[H");

      --  Draw header
      Ada.Text_IO.Put_Line ("╔══════════════════════════════════════════════════════════════╗");
      Ada.Text_IO.Put_Line ("║  REPOSYSTEM - Railway Yard for Your Repository Ecosystem     ║");
      Ada.Text_IO.Put_Line ("╠══════════════════════════════════════════════════════════════╣");

      --  Draw mode indicator
      Ada.Text_IO.Put ("║  Mode: ");
      case State.Mode is
         when Graph_View    => Ada.Text_IO.Put ("[GRAPH]");
         when List_View     => Ada.Text_IO.Put ("[LIST] ");
         when Detail_View   => Ada.Text_IO.Put ("[DETAIL]");
         when Scenario_View => Ada.Text_IO.Put ("[SCENARIO]");
      end case;
      Ada.Text_IO.Put ("  Filter: ");
      case State.Filter is
         when All_Aspects  => Ada.Text_IO.Put ("[ALL]");
         when Security     => Ada.Text_IO.Put ("[SECURITY]");
         when Reliability  => Ada.Text_IO.Put ("[RELIABILITY]");
         when Performance  => Ada.Text_IO.Put ("[PERFORMANCE]");
         when Supply_Chain => Ada.Text_IO.Put ("[SUPPLY-CHAIN]");
         when Compliance   => Ada.Text_IO.Put ("[COMPLIANCE]");
      end case;
      Ada.Text_IO.New_Line;

      Ada.Text_IO.Put_Line ("╠══════════════════════════════════════════════════════════════╣");
      Ada.Text_IO.Put_Line ("║  Repos:" & Natural'Image (State.Repo_Count) &
                            "  Edges:" & Natural'Image (State.Edge_Count) &
                            "  Selected:" & Natural'Image (State.Selected));
      Ada.Text_IO.Put_Line ("╚══════════════════════════════════════════════════════════════╝");

      --  Draw status line
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("  [1-4] View  [a/s/r/p] Filter  [hjkl] Navigate  [q] Quit");
   end Render;

   --  Shutdown application
   procedure Shutdown (State : in out App_State) is
   begin
      State.Running := False;
   end Shutdown;

   --  Main event loop
   procedure Run (Width : Screen_Width; Height : Screen_Height) is
      pragma SPARK_Mode (Off);  --  I/O operations not in SPARK
      State : App_State := Initialize (Width, Height);
      Key   : Character;
   begin
      while State.Running loop
         Render (State);
         Ada.Text_IO.Get_Immediate (Key);
         Handle_Input (State, Key);
      end loop;

      --  Clear screen on exit
      Ada.Text_IO.Put (ASCII.ESC & "[2J" & ASCII.ESC & "[H");
   end Run;

end Reposystem_TUI;
