-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

--  Gitvisor.Config - Configuration management
--
--  Handles loading and saving user configuration.

package Gitvisor.Config is

   type Settings is record
      API_Endpoint     : URL_String := (others => ' ');
      Endpoint_Length  : Natural := 0;
      GitHub_Token     : String (1 .. 256) := (others => ' ');
      GitHub_Token_Len : Natural := 0;
      GitLab_Token     : String (1 .. 256) := (others => ' ');
      GitLab_Token_Len : Natural := 0;
      Default_Platform : Platform_Type := GitHub;
      Theme            : String (1 .. 32) := "dark                            ";
   end record;

   --  Load configuration from file
   procedure Load (Config : out Settings);

   --  Save configuration to file
   procedure Save (Config : in Settings);

   --  Get config file path
   function Config_Path return String;

end Gitvisor.Config;
