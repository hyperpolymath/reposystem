-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
--
-- bitfuckit - The Bitbucket CLI Atlassian never made
-- A fault-tolerant, enterprise-grade Bitbucket CLI in Ada/SPARK
--
-- Credential resolution order:
--   1. RGTV (Svalinn vault) - post-quantum encrypted identity store
--   2. Environment variables (BITBUCKET_USERNAME, BITBUCKET_API_TOKEN,
--      BITBUCKET_WORKSPACE)
--   3. Config file (~/.config/bitfuckit/config)
--   4. ~/.netrc (machine bitbucket.org)

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Command_Line; use Ada.Command_Line;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;
with Bitbucket_API;
with TUI;
with RGTV;
use type RGTV.Credential_Source;
with GNAT.OS_Lib;

procedure Bitfuckit is

   Version_String : constant String := "0.2.0";
   Build_Date     : constant String := "2025-12";

   procedure Print_Version is
   begin
      Put_Line ("bitfuckit " & Version_String);
      Put_Line ("Build: " & Build_Date);
      Put_Line ("Language: Ada/SPARK 2012");
      Put_Line ("License: PMPL-1.0-or-later");
      Put_Line ("");
      Put_Line ("Features:");
      Put_Line ("  - Bitbucket Cloud API integration");
      Put_Line ("  - Git LFS support");
      Put_Line ("  - Circuit breaker fault tolerance");
      Put_Line ("  - Network-aware operation");
      Put_Line ("  - SELinux/firewalld integration");
      Put_Line ("");
      Put_Line ("https://github.com/hyperpolymath/bitfuckit");
   end Print_Version;

   procedure Print_Usage is
   begin
      Put_Line ("bitfuckit " & Version_String & " - The Bitbucket CLI Atlassian never made");
      Put_Line ("");
      Put_Line ("USAGE:");
      Put_Line ("  bitfuckit [command] [subcommand] [options]");
      Put_Line ("  bitfuckit                             Launch TUI interface");
      Put_Line ("");
      Put_Line ("AUTHENTICATION:");
      Put_Line ("  auth login                            Login with API token");
      Put_Line ("  auth status                           Show auth status and source");
      Put_Line ("  auth logout                           Remove credentials");
      Put_Line ("");
      Put_Line ("CREDENTIAL SOURCES (checked in order):");
      Put_Line ("  1. RGTV (Svalinn vault)               Secure, recommended");
      Put_Line ("  2. Environment variables               BITBUCKET_API_TOKEN");
      Put_Line ("  3. Config file                         ~/.config/bitfuckit/config");
      Put_Line ("  4. ~/.netrc                            Standard netrc format");
      Put_Line ("");
      Put_Line ("REPOSITORIES:");
      Put_Line ("  repo create <name> [options]          Create repository");
      Put_Line ("       --private                        Make repo private");
      Put_Line ("       --description ""text""             Set description");
      Put_Line ("  repo list                             List repositories");
      Put_Line ("  repo delete <name>                    Delete repository");
      Put_Line ("  repo exists <name>                    Check if repo exists");
      Put_Line ("");
      Put_Line ("PULL REQUESTS:");
      Put_Line ("  pr list <repo> [options]              List pull requests");
      Put_Line ("       --state STATE                    OPEN, MERGED, DECLINED");
      Put_Line ("       --all                            Show all states");
      Put_Line ("");
      Put_Line ("MIRRORING:");
      Put_Line ("  mirror <name>                         Mirror to Bitbucket");
      Put_Line ("");
      Put_Line ("GIT LFS:");
      Put_Line ("  lfs status                            Show LFS status");
      Put_Line ("  lfs track <pattern>                   Track files with LFS");
      Put_Line ("  lfs fetch                             Fetch LFS objects");
      Put_Line ("  lfs pull                              Pull LFS objects");
      Put_Line ("  lfs push                              Push LFS objects");
      Put_Line ("");
      Put_Line ("NETWORK:");
      Put_Line ("  network status                        Show network state");
      Put_Line ("  network check                         Check API connectivity");
      Put_Line ("");
      Put_Line ("INTERFACE:");
      Put_Line ("  tui                                   Launch TUI interface");
      Put_Line ("  troubleshoot                          Run troubleshooter");
      Put_Line ("");
      Put_Line ("OPTIONS:");
      Put_Line ("  -h, --help                            Show this help");
      Put_Line ("  -V, --version                         Show version");
      Put_Line ("  -q, --quiet                           Suppress output");
      Put_Line ("  -v, --verbose                         Verbose output");
      Put_Line ("      --no-color                        Disable colors");
      Put_Line ("      --offline                         Use cached data only");
      Put_Line ("");
      Put_Line ("EXAMPLES:");
      Put_Line ("  bitfuckit auth login");
      Put_Line ("  bitfuckit repo create my-project --private");
      Put_Line ("  bitfuckit pr list my-project --all");
      Put_Line ("  bitfuckit mirror my-project");
      Put_Line ("  bitfuckit lfs track ""*.psd""");
      Put_Line ("");
      Put_Line ("DOCUMENTATION:");
      Put_Line ("  man bitfuckit                         View man page");
      Put_Line ("  Wiki: https://github.com/hyperpolymath/bitfuckit/wiki");
      Put_Line ("  API tokens: https://id.atlassian.com/manage-profile/security/api-tokens");
      Put_Line ("  RGTV: https://github.com/hyperpolymath/reasonably-good-token-vault");
   end Print_Usage;

   procedure Print_Troubleshoot_Menu is
   begin
      Put_Line ("bitfuckit troubleshooter");
      Put_Line ("");
      Put_Line ("Common issues and solutions:");
      Put_Line ("");
      Put_Line ("1. AUTHENTICATION");
      Put_Line ("   Error: Not logged in");
      Put_Line ("   Fix: Run 'bitfuckit auth login' or store in RGTV");
      Put_Line ("   RGTV: svalinn-cli add rest-api --host bitbucket.org");
      Put_Line ("   Docs: https://github.com/hyperpolymath/bitfuckit/wiki/Authentication");
      Put_Line ("");
      Put_Line ("2. API TOKEN");
      Put_Line ("   Error: 401 Unauthorized");
      Put_Line ("   Fix: Generate an Atlassian API token with required scopes");
      Put_Line ("   Link: https://id.atlassian.com/manage-profile/security/api-tokens");
      Put_Line ("   Required scopes: repository:read, repository:write, pullrequest:read");
      Put_Line ("");
      Put_Line ("3. NETWORK ISSUES");
      Put_Line ("   Error: Connection refused / timeout");
      Put_Line ("   Fix: Check internet, proxy settings, firewall");
      Put_Line ("   Check: bitfuckit network status");
      Put_Line ("   Docs: https://github.com/hyperpolymath/bitfuckit/wiki/Network");
      Put_Line ("");
      Put_Line ("4. GIT LFS");
      Put_Line ("   Error: LFS not installed / not configured");
      Put_Line ("   Fix: Install git-lfs, run 'git lfs install'");
      Put_Line ("   Check: bitfuckit lfs status");
      Put_Line ("   Docs: https://github.com/hyperpolymath/bitfuckit/wiki/Git-LFS");
      Put_Line ("");
      Put_Line ("5. RATE LIMITING");
      Put_Line ("   Error: 429 Too Many Requests");
      Put_Line ("   Fix: Wait for circuit breaker reset (30s)");
      Put_Line ("   Note: bitfuckit auto-retries with backoff");
      Put_Line ("   Docs: https://github.com/hyperpolymath/bitfuckit/wiki/Rate-Limits");
      Put_Line ("");
      Put_Line ("6. SSH KEYS");
      Put_Line ("   Error: Permission denied (publickey)");
      Put_Line ("   Fix: Add SSH key to Bitbucket account");
      Put_Line ("   Link: https://bitbucket.org/account/settings/ssh-keys/");
      Put_Line ("   Docs: https://github.com/hyperpolymath/bitfuckit/wiki/SSH-Keys");
      Put_Line ("");
      Put_Line ("For more help: https://github.com/hyperpolymath/bitfuckit/issues");
   end Print_Troubleshoot_Menu;

   procedure Do_Auth_Login is
      Username : Unbounded_String;
      Password : Unbounded_String;
      Workspace : Unbounded_String;
      Creds : Config.Credentials;
      Line : String (1 .. 256);
      Last : Natural;
   begin
      Put ("Bitbucket username: ");
      Get_Line (Line, Last);
      Username := To_Unbounded_String (Line (1 .. Last));

      Put ("Atlassian API token: ");
      Get_Line (Line, Last);
      Password := To_Unbounded_String (Line (1 .. Last));

      Put ("Workspace (usually same as username): ");
      Get_Line (Line, Last);
      Workspace := To_Unbounded_String (Line (1 .. Last));

      if Length (Workspace) = 0 then
         Workspace := Username;
      end if;

      Creds := (Username => Username,
                App_Password => Password,
                Workspace => Workspace);

      Config.Save_Credentials (Creds);
      Put_Line ("Credentials saved to " & Config.Get_Config_File);

      -- Test the credentials
      declare
         Result : constant Bitbucket_API.API_Result :=
            Bitbucket_API.List_Repos (Creds);
      begin
         if Result.Success then
            Put_Line ("Authentication successful!");
         else
            Put_Line ("Warning: Could not verify credentials");
         end if;
      end;
   end Do_Auth_Login;

   procedure Do_Auth_Status is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
   begin
      RGTV.Resolve_Credentials (Creds, Source);

      if Source /= RGTV.Source_None then
         Put_Line ("Logged in as: " & To_String (Creds.Username));
         Put_Line ("Workspace: " & To_String (Creds.Workspace));
         Put_Line ("Source: " & RGTV.Source_Label (Source));

         -- Show RGTV vault status
         if RGTV.Is_Available then
            if RGTV.Is_Unlocked then
               Put_Line ("RGTV: available (vault unlocked)");
            else
               Put_Line ("RGTV: available (vault locked)");
            end if;
         else
            Put_Line ("RGTV: not installed (install svalinn-cli for " &
                      "secure credential storage)");
         end if;
      else
         Put_Line ("Not logged in.");
         Put_Line ("");
         Put_Line ("Credential sources checked (in priority order):");
         Put_Line ("  1. RGTV (Svalinn vault) - " &
                   (if RGTV.Is_Available then
                      (if RGTV.Is_Unlocked then
                         "available, no bitbucket.org identity found"
                       else "available but vault is locked")
                    else "not installed"));
         Put_Line ("  2. Environment variables - not set");
         Put_Line ("  3. Config file - " & Config.Get_Config_File);
         Put_Line ("  4. ~/.netrc - no bitbucket.org entry");
         Put_Line ("");
         Put_Line ("To authenticate, use one of:");
         Put_Line ("  bitfuckit auth login              " &
                   "(saves to config file)");
         Put_Line ("  svalinn-cli add rest-api " &
                   "--host bitbucket.org  (RGTV, recommended)");
         Put_Line ("  export BITBUCKET_USERNAME=... " &
                   "BITBUCKET_API_TOKEN=...  (env vars)");
      end if;
   end Do_Auth_Status;

   procedure Do_Repo_Create is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
      Name : Unbounded_String := Null_Unbounded_String;
      Description : Unbounded_String := Null_Unbounded_String;
      Is_Private : Boolean := False;
      I : Integer := 3;
   begin
      RGTV.Resolve_Credentials (Creds, Source);
      if Source = RGTV.Source_None then
         Put_Line ("Error: Not logged in. Run: bitfuckit auth login");
         Set_Exit_Status (1);
         return;
      end if;

      while I <= Argument_Count loop
         declare
            Arg : constant String := Argument (I);
         begin
            if Arg = "--private" then
               Is_Private := True;
            elsif Arg = "--description" and then I < Argument_Count then
               I := I + 1;
               Description := To_Unbounded_String (Argument (I));
            elsif Length (Name) = 0 then
               Name := To_Unbounded_String (Arg);
            end if;
         end;
         I := I + 1;
      end loop;

      if Length (Name) = 0 then
         Put_Line ("Error: Repository name required");
         Set_Exit_Status (1);
         return;
      end if;

      Put ("Creating repository " & To_String (Name) & "... ");
      declare
         Result : constant Bitbucket_API.API_Result :=
            Bitbucket_API.Create_Repo
              (Creds, To_String (Name), Is_Private, To_String (Description));
      begin
         if Result.Success then
            Put_Line ("done!");
            Put_Line ("https://bitbucket.org/" &
                      To_String (Creds.Workspace) & "/" &
                      To_String (Name));
         else
            Put_Line ("failed!");
            Put_Line (To_String (Result.Message));
            Set_Exit_Status (1);
         end if;
      end;
   end Do_Repo_Create;

   procedure Do_Repo_List is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
   begin
      RGTV.Resolve_Credentials (Creds, Source);
      if Source = RGTV.Source_None then
         Put_Line ("Error: Not logged in. Run: bitfuckit auth login");
         Set_Exit_Status (1);
         return;
      end if;

      declare
         Result : constant Bitbucket_API.API_Result :=
            Bitbucket_API.List_Repos (Creds);
         Data : constant String := To_String (Result.Data);
         Pos : Natural := 1;
         Slug_Start : Natural;
         Slug_End : Natural;
      begin
         if not Result.Success then
            Put_Line ("Error: " & To_String (Result.Message));
            Set_Exit_Status (1);
            return;
         end if;

         Put_Line ("Repositories in " & To_String (Creds.Workspace) & ":");
         Put_Line ("");

         -- Simple JSON parsing for slugs
         loop
            Slug_Start := Ada.Strings.Unbounded.Index
              (Result.Data, """slug"": """, Pos);
            exit when Slug_Start = 0;

            Slug_Start := Slug_Start + 9;
            Slug_End := Ada.Strings.Unbounded.Index
              (Result.Data, """", Slug_Start);
            exit when Slug_End = 0;

            Put_Line ("  " & Slice (Result.Data, Slug_Start, Slug_End - 1));
            Pos := Slug_End + 1;
         end loop;
      end;
   end Do_Repo_List;

   procedure Do_Repo_Delete is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
      Name : constant String := (if Argument_Count >= 3
                                  then Argument (3)
                                  else "");
      Confirm : String (1 .. 10);
      Last : Natural;
   begin
      RGTV.Resolve_Credentials (Creds, Source);
      if Source = RGTV.Source_None then
         Put_Line ("Error: Not logged in. Run: bitfuckit auth login");
         Set_Exit_Status (1);
         return;
      end if;

      if Name'Length = 0 then
         Put_Line ("Error: Repository name required");
         Set_Exit_Status (1);
         return;
      end if;

      Put ("Delete repository " & Name & "? Type 'yes' to confirm: ");
      Get_Line (Confirm, Last);

      if Confirm (1 .. Last) /= "yes" then
         Put_Line ("Aborted.");
         return;
      end if;

      declare
         Result : constant Bitbucket_API.API_Result :=
            Bitbucket_API.Delete_Repo (Creds, Name);
      begin
         if Result.Success then
            Put_Line ("Deleted: " & Name);
         else
            Put_Line ("Error: " & To_String (Result.Message));
            Set_Exit_Status (1);
         end if;
      end;
   end Do_Repo_Delete;

   procedure Do_Repo_Exists is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
      Name : constant String := (if Argument_Count >= 3
                                  then Argument (3)
                                  else "");
   begin
      RGTV.Resolve_Credentials (Creds, Source);
      if Source = RGTV.Source_None then
         Put_Line ("Error: Not logged in. Run: bitfuckit auth login");
         Set_Exit_Status (1);
         return;
      end if;

      if Name'Length = 0 then
         Put_Line ("Error: Repository name required");
         Set_Exit_Status (1);
         return;
      end if;

      if Bitbucket_API.Repo_Exists (Creds, Name) then
         Put_Line ("Repository exists: " & Name);
      else
         Put_Line ("Repository not found: " & Name);
         Set_Exit_Status (1);
      end if;
   end Do_Repo_Exists;

   procedure Do_PR_List is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
      Repo_Name : Unbounded_String := Null_Unbounded_String;
      State : Unbounded_String := To_Unbounded_String ("OPEN");
      I : Integer := 3;
   begin
      RGTV.Resolve_Credentials (Creds, Source);
      if Source = RGTV.Source_None then
         Put_Line ("Error: Not logged in. Run: bitfuckit auth login");
         Set_Exit_Status (1);
         return;
      end if;

      -- Parse arguments
      while I <= Argument_Count loop
         declare
            Arg : constant String := Argument (I);
         begin
            if Arg = "--state" and then I < Argument_Count then
               I := I + 1;
               State := To_Unbounded_String (Argument (I));
            elsif Arg = "--all" then
               State := Null_Unbounded_String;
            elsif Length (Repo_Name) = 0 then
               Repo_Name := To_Unbounded_String (Arg);
            end if;
         end;
         I := I + 1;
      end loop;

      if Length (Repo_Name) = 0 then
         Put_Line ("Error: Repository name required");
         Put_Line ("Usage: bitfuckit pr list <repo> [--state STATE]");
         Set_Exit_Status (1);
         return;
      end if;

      declare
         Result : constant Bitbucket_API.API_Result :=
            Bitbucket_API.List_Pull_Requests
              (Creds, To_String (Repo_Name), To_String (State));
         Data : constant String := To_String (Result.Data);
         Pos : Natural := 1;
         ID_Start, ID_End : Natural;
         Title_Start, Title_End : Natural;
         State_Start, State_End : Natural;
         Author_Start, Author_End : Natural;
         PR_Count : Natural := 0;
      begin
         if not Result.Success then
            Put_Line ("Error: " & To_String (Result.Message));
            Set_Exit_Status (1);
            return;
         end if;

         Put_Line ("Pull Requests in " & To_String (Repo_Name) & ":");
         Put_Line ("");

         -- Parse JSON for pull requests
         loop
            -- Find PR ID
            ID_Start := Ada.Strings.Unbounded.Index (Result.Data, """id"": ", Pos);
            exit when ID_Start = 0;

            ID_Start := ID_Start + 6;
            ID_End := ID_Start;
            while ID_End <= Length (Result.Data) and then
                  Element (Result.Data, ID_End) in '0' .. '9'
            loop
               ID_End := ID_End + 1;
            end loop;

            -- Find title
            Title_Start := Ada.Strings.Unbounded.Index
              (Result.Data, """title"": """, ID_End);
            if Title_Start > 0 then
               Title_Start := Title_Start + 10;
               Title_End := Ada.Strings.Unbounded.Index
                 (Result.Data, """", Title_Start);
            else
               Title_Start := 1;
               Title_End := 1;
            end if;

            -- Find state
            State_Start := Ada.Strings.Unbounded.Index
              (Result.Data, """state"": """, ID_End);
            if State_Start > 0 then
               State_Start := State_Start + 10;
               State_End := Ada.Strings.Unbounded.Index
                 (Result.Data, """", State_Start);
            else
               State_Start := 1;
               State_End := 1;
            end if;

            -- Find author
            Author_Start := Ada.Strings.Unbounded.Index
              (Result.Data, """display_name"": """, ID_End);
            if Author_Start > 0 then
               Author_Start := Author_Start + 17;
               Author_End := Ada.Strings.Unbounded.Index
                 (Result.Data, """", Author_Start);
            else
               Author_Start := 1;
               Author_End := 1;
            end if;

            -- Print PR info
            Put ("#" & Slice (Result.Data, ID_Start, ID_End - 1));
            if State_End > State_Start then
               Put (" [" & Slice (Result.Data, State_Start, State_End - 1) & "]");
            end if;
            if Title_End > Title_Start then
               Put (" " & Slice (Result.Data, Title_Start, Title_End - 1));
            end if;
            if Author_End > Author_Start then
               Put (" (" & Slice (Result.Data, Author_Start, Author_End - 1) & ")");
            end if;
            New_Line;

            PR_Count := PR_Count + 1;
            Pos := ID_End + 100;  -- Skip ahead to next PR object
         end loop;

         if PR_Count = 0 then
            Put_Line ("  No pull requests found.");
         else
            New_Line;
            Put_Line ("Total:" & PR_Count'Image & " pull request(s)");
         end if;
      end;
   end Do_PR_List;

   procedure Do_Mirror is
      Creds  : Config.Credentials;
      Source : RGTV.Credential_Source;
      Name : constant String := (if Argument_Count >= 2
                                  then Argument (2)
                                  else "");
      Result : Bitbucket_API.API_Result;
      Push_Result : Integer;
      Args : GNAT.OS_Lib.Argument_List_Access;
   begin
      RGTV.Resolve_Credentials (Creds, Source);
      if Source = RGTV.Source_None then
         Put_Line ("Error: Not logged in. Run: bitfuckit auth login");
         Set_Exit_Status (1);
         return;
      end if;

      if Name'Length = 0 then
         Put_Line ("Error: Repository name required");
         Put_Line ("Usage: bitfuckit mirror <repo-name>");
         Set_Exit_Status (1);
         return;
      end if;

      -- Create repo if it doesn't exist
      if not Bitbucket_API.Repo_Exists (Creds, Name) then
         Put ("Creating repository " & Name & "... ");
         Result := Bitbucket_API.Create_Repo (Creds, Name, False, "");
         if Result.Success then
            Put_Line ("done!");
         else
            Put_Line ("failed!");
            Set_Exit_Status (1);
            return;
         end if;
      else
         Put_Line ("Repository exists: " & Name);
      end if;

      -- Push to Bitbucket
      Put_Line ("Pushing to Bitbucket...");
      Args := GNAT.OS_Lib.Argument_String_To_List
        ("push --all git@bitbucket.org:" &
         To_String (Creds.Workspace) & "/" & Name & ".git");

      Push_Result := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/git",
         Args => Args.all);

      if Push_Result = 0 then
         Put_Line ("Mirror complete!");
         Put_Line ("https://bitbucket.org/" &
                   To_String (Creds.Workspace) & "/" & Name);
      else
         Put_Line ("Push failed with exit code:" & Push_Result'Image);
         Set_Exit_Status (1);
      end if;
   end Do_Mirror;

begin
   if Argument_Count = 0 then
      TUI.Run_TUI;
      return;
   end if;

   declare
      Cmd : constant String := Argument (1);
      Sub : constant String := (if Argument_Count >= 2
                                 then Argument (2)
                                 else "");
   begin
      if Cmd = "auth" then
         if Sub = "login" then
            Do_Auth_Login;
         elsif Sub = "status" then
            Do_Auth_Status;
         else
            Put_Line ("Unknown auth command. Use: login, status");
            Set_Exit_Status (1);
         end if;

      elsif Cmd = "repo" then
         if Sub = "create" then
            Do_Repo_Create;
         elsif Sub = "list" then
            Do_Repo_List;
         elsif Sub = "delete" then
            Do_Repo_Delete;
         elsif Sub = "exists" then
            Do_Repo_Exists;
         else
            Put_Line ("Unknown repo command. Use: create, list, delete, exists");
            Set_Exit_Status (1);
         end if;

      elsif Cmd = "pr" then
         if Sub = "list" then
            Do_PR_List;
         else
            Put_Line ("Unknown pr command. Use: list");
            Set_Exit_Status (1);
         end if;

      elsif Cmd = "mirror" then
         Do_Mirror;

      elsif Cmd = "tui" then
         TUI.Run_TUI;

      elsif Cmd = "help" or else Cmd = "--help" or else Cmd = "-h" then
         Print_Usage;

      elsif Cmd = "--version" or else Cmd = "-V" or else Cmd = "version" then
         Print_Version;

      elsif Cmd = "troubleshoot" then
         Print_Troubleshoot_Menu;

      elsif Cmd = "lfs" then
         Put_Line ("Git LFS commands:");
         Put_Line ("  lfs status    - Show LFS status");
         Put_Line ("  lfs track     - Track files with LFS");
         Put_Line ("  lfs fetch     - Fetch LFS objects");
         Put_Line ("  lfs pull      - Pull LFS objects");
         Put_Line ("  lfs push      - Push LFS objects");
         Put_Line ("");
         Put_Line ("Run 'bitfuckit lfs <command>' for details.");

      elsif Cmd = "network" then
         Put_Line ("Network commands:");
         Put_Line ("  network status  - Show network state");
         Put_Line ("  network check   - Check API connectivity");

      else
         Put_Line ("Unknown command: " & Cmd);
         Put_Line ("Run 'bitfuckit --help' for usage information.");
         Set_Exit_Status (1);
      end if;
   end;
end Bitfuckit;
