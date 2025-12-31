-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
--
-- reposystem_tui-main.adb - Main entry point for Ada/SPARK TUI

with Reposystem_TUI;
with Ada.Command_Line;
with Ada.Text_IO;

procedure Reposystem_TUI.Main is
   Width  : Screen_Width  := 80;
   Height : Screen_Height := 24;
begin
   --  Parse command line arguments for dimensions
   if Ada.Command_Line.Argument_Count >= 2 then
      begin
         Width := Screen_Width'Value (Ada.Command_Line.Argument (1));
         Height := Screen_Height'Value (Ada.Command_Line.Argument (2));
      exception
         when others =>
            Ada.Text_IO.Put_Line ("Usage: reposystem-tui [width height]");
            Ada.Text_IO.Put_Line ("  width:  1-1000 (default: 80)");
            Ada.Text_IO.Put_Line ("  height: 1-500 (default: 24)");
            return;
      end;
   end if;

   --  Run the TUI
   Reposystem_TUI.Run (Width, Height);
end Reposystem_TUI.Main;
