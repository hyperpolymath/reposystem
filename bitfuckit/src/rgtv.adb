-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- RGTV (Reasonably Good Token Vault) integration for bitfuckit.
--
-- Implementation notes:
--   - Shells out to svalinn-cli for vault queries. This avoids a
--     compile-time dependency on the Svalinn Rust core and keeps
--     the integration optional.
--   - All subprocess output is parsed defensively; any parse
--     failure returns No_Credentials so the cascade continues.
--   - The .netrc parser handles the standard machine/login/password
--     triple format used by curl and other network tools.

with Ada.Environment_Variables;
with Ada.Directories;
with Ada.Text_IO;
with Ada.IO_Exceptions;
with Ada.Strings;
with Ada.Strings.Fixed;    use Ada.Strings.Fixed;
with GNAT.Expect;
with GNAT.OS_Lib;

package body RGTV is

   -- -----------------------------------------------------------------------
   -- Internal helpers
   -- -----------------------------------------------------------------------

   -- Run a command and capture its stdout. Returns empty string on failure.
   function Run_Command (Program : String; Args : String) return String is
      use GNAT.Expect;
      Pd     : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
   begin
      Non_Blocking_Spawn
        (Pd,
         Program,
         GNAT.OS_Lib.Argument_String_To_List (Args).all,
         Err_To_Out => False);

      loop
         begin
            Expect (Pd, Result, ".+", Timeout => 5_000);
            Append (Output, Expect_Out (Pd));
         exception
            when Process_Died =>
               exit;
         end;
      end loop;

      Close (Pd);
      return To_String (Output);

   exception
      when others =>
         return "";
   end Run_Command;

   -- Locate svalinn-cli on PATH by checking common locations.
   -- Returns the full path or empty string if not found.
   function Find_Svalinn_CLI return String is
      Candidates : constant array (1 .. 4) of access constant String :=
        (new String'("/usr/local/bin/svalinn-cli"),
         new String'("/usr/bin/svalinn-cli"),
         new String'(Ada.Environment_Variables.Value ("HOME") &
                     "/.local/bin/svalinn-cli"),
         new String'(Ada.Environment_Variables.Value ("HOME") &
                     "/.cargo/bin/svalinn-cli"));
   begin
      for Path of Candidates loop
         if Ada.Directories.Exists (Path.all) then
            return Path.all;
         end if;
      end loop;

      -- Try 'which' as fallback
      declare
         Which_Result : constant String :=
            Run_Command ("/usr/bin/which", "svalinn-cli");
         Trimmed      : constant String :=
            Trim (Which_Result, Ada.Strings.Both);
      begin
         if Trimmed'Length > 0
           and then Ada.Directories.Exists (Trimmed)
         then
            return Trimmed;
         end if;
      end;

      return "";
   end Find_Svalinn_CLI;

   -- Extract a value from a line of the form "key: value" or "key=value".
   -- Returns empty string if not found.
   function Extract_Field
     (Output : String;
      Key    : String) return String
   is
      -- Search for "key: value" format (svalinn-cli output)
      Colon_Pattern : constant String := Key & ": ";
      Eq_Pattern    : constant String := Key & "=";
      Pos           : Natural;
      Line_End      : Natural;
   begin
      -- Try "key: value"
      Pos := Index (Output, Colon_Pattern);
      if Pos > 0 then
         Pos := Pos + Colon_Pattern'Length;
         Line_End := Index (Output, "" & ASCII.LF, Pos);
         if Line_End = 0 then
            Line_End := Output'Last + 1;
         end if;
         return Trim (Output (Pos .. Line_End - 1), Ada.Strings.Both);
      end if;

      -- Try "key=value"
      Pos := Index (Output, Eq_Pattern);
      if Pos > 0 then
         Pos := Pos + Eq_Pattern'Length;
         Line_End := Index (Output, "" & ASCII.LF, Pos);
         if Line_End = 0 then
            Line_End := Output'Last + 1;
         end if;
         return Trim (Output (Pos .. Line_End - 1), Ada.Strings.Both);
      end if;

      return "";
   end Extract_Field;

   -- Check if a Credentials record is complete (all three fields non-empty)
   function Is_Complete (Creds : Config.Credentials) return Boolean is
   begin
      return Length (Creds.Username) > 0
        and then Length (Creds.App_Password) > 0
        and then Length (Creds.Workspace) > 0;
   end Is_Complete;

   -- Load credentials from environment variables:
   --   BITBUCKET_USERNAME, BITBUCKET_API_TOKEN, BITBUCKET_WORKSPACE
   function Load_From_Environment return Config.Credentials is
      Result : Config.Credentials := Config.No_Credentials;
   begin
      if Ada.Environment_Variables.Exists ("BITBUCKET_USERNAME") then
         Result.Username := To_Unbounded_String
           (Ada.Environment_Variables.Value ("BITBUCKET_USERNAME"));
      end if;

      if Ada.Environment_Variables.Exists ("BITBUCKET_API_TOKEN") then
         Result.App_Password := To_Unbounded_String
           (Ada.Environment_Variables.Value ("BITBUCKET_API_TOKEN"));
      end if;

      -- Fall back to legacy env var name if new one is not set
      if Length (Result.App_Password) = 0
        and then Ada.Environment_Variables.Exists ("BITBUCKET_APP_PASSWORD")
      then
         Result.App_Password := To_Unbounded_String
           (Ada.Environment_Variables.Value ("BITBUCKET_APP_PASSWORD"));
      end if;

      if Ada.Environment_Variables.Exists ("BITBUCKET_WORKSPACE") then
         Result.Workspace := To_Unbounded_String
           (Ada.Environment_Variables.Value ("BITBUCKET_WORKSPACE"));
      end if;

      -- If workspace is empty but username is set, default workspace to
      -- username (Bitbucket convention).
      if Length (Result.Workspace) = 0
        and then Length (Result.Username) > 0
      then
         Result.Workspace := Result.Username;
      end if;

      return Result;
   end Load_From_Environment;

   -- Load credentials from ~/.netrc.
   -- Parses the standard machine/login/password triple for bitbucket.org.
   -- The "password" field is treated as the Atlassian API token.
   -- Workspace defaults to login (username) if not available.
   function Load_From_Netrc return Config.Credentials is
      Home    : constant String := Ada.Environment_Variables.Value ("HOME");
      Netrc   : constant String := Home & "/.netrc";
      File    : Ada.Text_IO.File_Type;
      Result  : Config.Credentials := Config.No_Credentials;
      In_BB   : Boolean := False;  -- Currently inside a bitbucket.org block
   begin
      if not Ada.Directories.Exists (Netrc) then
         return Config.No_Credentials;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Netrc);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line    : constant String := Ada.Text_IO.Get_Line (File);
            Trimmed : constant String := Trim (Line, Ada.Strings.Both);
            Tok_Pos : Natural;
         begin
            -- Check for "machine bitbucket.org" (or api.bitbucket.org)
            if Index (Trimmed, "machine") = Trimmed'First then
               declare
                  Host : constant String :=
                     Trim (Trimmed (Trimmed'First + 7 .. Trimmed'Last),
                           Ada.Strings.Both);
               begin
                  In_BB := Host = "bitbucket.org"
                    or else Host = "api.bitbucket.org";
               end;
            end if;

            if In_BB then
               -- Parse "login <username>"
               Tok_Pos := Index (Trimmed, "login");
               if Tok_Pos = Trimmed'First then
                  Result.Username := To_Unbounded_String
                    (Trim (Trimmed (Trimmed'First + 5 .. Trimmed'Last),
                           Ada.Strings.Both));
               end if;

               -- Parse "password <token>"
               Tok_Pos := Index (Trimmed, "password");
               if Tok_Pos = Trimmed'First then
                  Result.App_Password := To_Unbounded_String
                    (Trim (Trimmed (Trimmed'First + 8 .. Trimmed'Last),
                           Ada.Strings.Both));
               end if;

               -- If we see the next "machine" keyword, stop
               if Index (Trimmed, "machine") = Trimmed'First
                 and then not (Trim (Trimmed (Trimmed'First + 7 ..
                                              Trimmed'Last),
                                     Ada.Strings.Both) = "bitbucket.org"
                               or else
                               Trim (Trimmed (Trimmed'First + 7 ..
                                              Trimmed'Last),
                                     Ada.Strings.Both) = "api.bitbucket.org")
               then
                  In_BB := False;
               end if;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);

      -- Workspace defaults to username for .netrc entries
      if Length (Result.Username) > 0
        and then Length (Result.Workspace) = 0
      then
         Result.Workspace := Result.Username;
      end if;

      return Result;

   exception
      when Ada.IO_Exceptions.Name_Error =>
         return Config.No_Credentials;
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return Config.No_Credentials;
   end Load_From_Netrc;

   -- -----------------------------------------------------------------------
   -- Public interface
   -- -----------------------------------------------------------------------

   function Is_Available return Boolean is
   begin
      return Find_Svalinn_CLI'Length > 0;
   end Is_Available;

   function Is_Unlocked return Boolean is
      CLI_Path : constant String := Find_Svalinn_CLI;
   begin
      if CLI_Path'Length = 0 then
         return False;
      end if;

      declare
         Output  : constant String := Run_Command (CLI_Path, "status");
         Trimmed : constant String := Trim (Output, Ada.Strings.Both);
      begin
         -- svalinn-cli status reports the vault state; look for "Unlocked"
         return Index (Trimmed, "Unlocked") > 0
           or else Index (Trimmed, "unlocked") > 0;
      end;

   exception
      when others =>
         return False;
   end Is_Unlocked;

   function Lookup_Credentials return Config.Credentials is
      CLI_Path : constant String := Find_Svalinn_CLI;
      Result   : Config.Credentials := Config.No_Credentials;
   begin
      if CLI_Path'Length = 0 then
         return Config.No_Credentials;
      end if;

      -- Query the vault for credentials associated with bitbucket.org.
      -- svalinn-cli get-by-host outputs key: value pairs for the identity.
      declare
         Output : constant String :=
            Run_Command (CLI_Path, "get-by-host bitbucket.org");
      begin
         if Output'Length = 0 then
            return Config.No_Credentials;
         end if;

         -- Parse fields from svalinn-cli output
         declare
            Username_Str  : constant String := Extract_Field (Output, "login");
            Token_Str     : constant String := Extract_Field (Output, "password");
            Workspace_Str : constant String := Extract_Field (Output, "workspace");
         begin
            if Username_Str'Length > 0 then
               Result.Username := To_Unbounded_String (Username_Str);
            end if;

            if Token_Str'Length > 0 then
               Result.App_Password := To_Unbounded_String (Token_Str);
            end if;

            if Workspace_Str'Length > 0 then
               Result.Workspace := To_Unbounded_String (Workspace_Str);
            elsif Username_Str'Length > 0 then
               -- Default workspace to username (Bitbucket convention)
               Result.Workspace := To_Unbounded_String (Username_Str);
            end if;
         end;
      end;

      return Result;

   exception
      when others =>
         return Config.No_Credentials;
   end Lookup_Credentials;

   procedure Resolve_Credentials
     (Creds  : out Config.Credentials;
      Source : out Credential_Source)
   is
   begin
      -- 1. RGTV (Svalinn vault) - preferred source
      Creds := Lookup_Credentials;
      if Is_Complete (Creds) then
         Source := Source_RGTV;
         return;
      end if;

      -- 2. Environment variables
      Creds := Load_From_Environment;
      if Is_Complete (Creds) then
         Source := Source_Environment;
         return;
      end if;

      -- 3. Config file (~/.config/bitfuckit/config)
      Creds := Config.Load_Credentials;
      if Is_Complete (Creds) then
         Source := Source_Config_File;
         return;
      end if;

      -- 4. ~/.netrc
      Creds := Load_From_Netrc;
      if Is_Complete (Creds) then
         Source := Source_Netrc;
         return;
      end if;

      -- Nothing found
      Creds  := Config.No_Credentials;
      Source := Source_None;
   end Resolve_Credentials;

   function Source_Label (S : Credential_Source) return String is
   begin
      case S is
         when Source_RGTV         => return "RGTV (Svalinn vault)";
         when Source_Environment  => return "environment variables";
         when Source_Config_File  => return "config file (" &
                                           Config.Get_Config_File & ")";
         when Source_Netrc        => return ".netrc";
         when Source_None         => return "none";
      end case;
   end Source_Label;

end RGTV;
