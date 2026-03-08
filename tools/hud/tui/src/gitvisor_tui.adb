-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

--  Gitvisor TUI - Terminal User Interface
--
--  A formally verified terminal interface for Git platform management.
--  Uses Ada/SPARK for memory safety and correctness guarantees.

with Ada.Text_IO;
with Ada.Command_Line;
with Gitvisor.UI;
with Gitvisor.Config;
with Gitvisor.API;

procedure Gitvisor_TUI is
   use Ada.Text_IO;

   Config : Gitvisor.Config.Settings;
   App    : Gitvisor.UI.Application;
begin
   --  Initialize configuration
   Gitvisor.Config.Load (Config);

   --  Parse command line arguments
   if Ada.Command_Line.Argument_Count > 0 then
      declare
         Arg : constant String := Ada.Command_Line.Argument (1);
      begin
         if Arg = "--version" or Arg = "-v" then
            Put_Line ("Gitvisor TUI v0.1.0");
            return;
         elsif Arg = "--help" or Arg = "-h" then
            Put_Line ("Gitvisor TUI - Terminal interface for Git platforms");
            New_Line;
            Put_Line ("Usage: gitvisor_tui [options]");
            New_Line;
            Put_Line ("Options:");
            Put_Line ("  -h, --help     Show this help message");
            Put_Line ("  -v, --version  Show version information");
            Put_Line ("  --config FILE  Use alternate config file");
            return;
         end if;
      end;
   end if;

   --  Initialize API connection
   Gitvisor.API.Initialize (Config);

   --  Create and run application
   Gitvisor.UI.Initialize (App, Config);
   Gitvisor.UI.Run (App);

   --  Cleanup
   Gitvisor.UI.Finalize (App);
   Gitvisor.API.Finalize;
end Gitvisor_TUI;
