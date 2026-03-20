-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- Config package for bitfuckit - handles credential storage.
-- For cascaded credential resolution (RGTV, env, config, netrc),
-- see the RGTV package.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Config is

   type Credentials is record
      Username : Unbounded_String;
      App_Password : Unbounded_String;
      Workspace : Unbounded_String;
   end record;

   No_Credentials : constant Credentials := (
      Username => Null_Unbounded_String,
      App_Password => Null_Unbounded_String,
      Workspace => Null_Unbounded_String
   );

   function Get_Config_Dir return String;
   function Get_Config_File return String;
   function Load_Credentials return Credentials;
   procedure Save_Credentials (Creds : Credentials);
   function Has_Credentials return Boolean;

end Config;
