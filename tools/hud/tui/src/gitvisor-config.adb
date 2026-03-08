-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

with Ada.Environment_Variables;
with Ada.Directories;

package body Gitvisor.Config is

   function Config_Path return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "/tmp");
   begin
      return Home & "/.config/gitvisor/config.toml";
   end Config_Path;

   procedure Load (Config : out Settings) is
      Path : constant String := Config_Path;
   begin
      --  Set defaults
      Config := (API_Endpoint     => (others => ' '),
                 Endpoint_Length  => 21,
                 GitHub_Token     => (others => ' '),
                 GitHub_Token_Len => 0,
                 GitLab_Token     => (others => ' '),
                 GitLab_Token_Len => 0,
                 Default_Platform => GitHub,
                 Theme            => "dark                            ");

      --  Set default endpoint
      Config.API_Endpoint (1 .. 21) := "http://localhost:4000";

      --  Try to load from file
      if Ada.Directories.Exists (Path) then
         --  TODO: Parse TOML config file
         null;
      end if;
   end Load;

   procedure Save (Config : in Settings) is
      pragma Unreferenced (Config);
      Path : constant String := Config_Path;
      Dir  : constant String := Ada.Directories.Containing_Directory (Path);
   begin
      --  Ensure directory exists
      if not Ada.Directories.Exists (Dir) then
         Ada.Directories.Create_Path (Dir);
      end if;

      --  TODO: Write TOML config file
      null;
   end Save;

end Gitvisor.Config;
