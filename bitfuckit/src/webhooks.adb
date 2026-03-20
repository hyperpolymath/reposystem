-- SPDX-License-Identifier: PMPL-1.0
-- Webhook management implementation

with GNAT.OS_Lib;
with GNAT.Expect;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;

package body Webhooks is

   Base_URL : constant String := "https://api.bitbucket.org/2.0";

   ---------------------------------------------------------------------------
   --  Internal: Execute curl command
   ---------------------------------------------------------------------------

   function Run_Curl (Args : String) return Webhook_Result is
      use GNAT.Expect;
      Pd     : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Ret    : Webhook_Result;
   begin
      Non_Blocking_Spawn
        (Pd,
         "/usr/bin/curl",
         GNAT.OS_Lib.Argument_String_To_List (Args).all,
         Err_To_Out => True);

      loop
         begin
            Expect (Pd, Result, ".+", Timeout => 60_000);
            Append (Output, Expect_Out (Pd));
         exception
            when Process_Died =>
               exit;
         end;
      end loop;

      Close (Pd);

      Ret.Data := Output;

      if Index (Output, """error""") > 0 or else
         Index (Output, """type"": ""error""") > 0
      then
         Ret.Success := False;
         Ret.Message := To_Unbounded_String ("API error in response");
      else
         Ret.Success := True;
         Ret.Message := To_Unbounded_String ("OK");
      end if;

      --  Extract UUID if present
      declare
         UUID_Pos : constant Natural := Index (Output, """uuid"": ""{");
      begin
         if UUID_Pos > 0 then
            declare
               Start_Pos : constant Natural := UUID_Pos + 10;
               End_Pos   : constant Natural := Index (Output, "}", Start_Pos);
               Data_Str  : constant String := To_String (Output);
            begin
               if End_Pos > Start_Pos then
                  Ret.Webhook_UUID := To_Unbounded_String
                    ("{" & Data_Str (Start_Pos .. End_Pos) & "}");
               end if;
            end;
         end if;
      end;

      return Ret;

   exception
      when others =>
         Ret.Success := False;
         Ret.Message := To_Unbounded_String ("Failed to execute curl");
         Ret.Data := Null_Unbounded_String;
         return Ret;
   end Run_Curl;

   function Auth_String (Creds : Config.Credentials) return String is
   begin
      return "-u " & To_String (Creds.Username) & ":" &
             To_String (Creds.App_Password);
   end Auth_String;

   function Repo_URL
     (Creds     : Config.Credentials;
      Repo_Name : String) return String
   is
   begin
      return Base_URL & "/repositories/" &
             To_String (Creds.Workspace) & "/" & Repo_Name;
   end Repo_URL;

   function Escape_JSON (S : String) return String is
      Result : Unbounded_String := Null_Unbounded_String;
   begin
      for C of S loop
         case C is
            when '"'  => Append (Result, "\""");
            when '\'  => Append (Result, "\\");
            when ASCII.LF => Append (Result, "\n");
            when ASCII.CR => Append (Result, "\r");
            when ASCII.HT => Append (Result, "\t");
            when others => Append (Result, C);
         end case;
      end loop;
      return To_String (Result);
   end Escape_JSON;

   ---------------------------------------------------------------------------
   --  Webhook CRUD
   ---------------------------------------------------------------------------

   function Create_Webhook
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      URL         : String;
      Description : String := "";
      Events      : Event_Set := Push_Events;
      Active      : Boolean := True;
      Secret      : String := "") return Webhook_Result
   is
      API_URL : constant String := Repo_URL (Creds, Repo_Name) & "/hooks";

      Active_Str : constant String :=
        (if Active then "true" else "false");

      Desc_Field : constant String :=
        (if Description'Length > 0
         then """description"":""" & Escape_JSON (Description) & ""","
         else "");

      Secret_Field : constant String :=
        (if Secret'Length > 0
         then ",""secret"":""" & Escape_JSON (Secret) & """"
         else "");

      Data : constant String :=
        "{""url"":""" & URL & """," &
        Desc_Field &
        """active"":" & Active_Str & "," &
        """events"":" & Events_To_JSON (Events) &
        Secret_Field & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & API_URL;
   begin
      return Run_Curl (Args);
   end Create_Webhook;

   function Get_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/hooks/" & Webhook_UUID;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Webhook;

   function List_Webhooks
     (Creds     : Config.Credentials;
      Repo_Name : String) return Webhook_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/hooks";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Webhooks;

   function Update_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String;
      URL          : String := "";
      Description  : String := "";
      Events       : String := "";
      Active       : String := "";
      Secret       : String := "") return Webhook_Result
   is
      API_URL : constant String := Repo_URL (Creds, Repo_Name) &
                                   "/hooks/" & Webhook_UUID;

      function Build_JSON return String is
         Result    : Unbounded_String := To_Unbounded_String ("{");
         Has_Field : Boolean := False;

         procedure Add_Field (Name, Value : String) is
         begin
            if Value'Length > 0 then
               if Has_Field then
                  Append (Result, ",");
               end if;
               Append (Result, """" & Name & """:""" &
                       Escape_JSON (Value) & """");
               Has_Field := True;
            end if;
         end Add_Field;

         procedure Add_Raw_Field (Name, Value : String) is
         begin
            if Value'Length > 0 then
               if Has_Field then
                  Append (Result, ",");
               end if;
               Append (Result, """" & Name & """:" & Value);
               Has_Field := True;
            end if;
         end Add_Raw_Field;
      begin
         Add_Field ("url", URL);
         Add_Field ("description", Description);
         Add_Raw_Field ("active", Active);
         Add_Field ("secret", Secret);

         if Events'Length > 0 then
            if Has_Field then
               Append (Result, ",");
            end if;
            Append (Result, """events"":[");
            --  Parse comma-separated events
            declare
               Pos    : Natural := Events'First;
               Start  : Natural;
               First  : Boolean := True;
            begin
               while Pos <= Events'Last loop
                  Start := Pos;
                  while Pos <= Events'Last and then Events (Pos) /= ',' loop
                     Pos := Pos + 1;
                  end loop;

                  if not First then
                     Append (Result, ",");
                  end if;
                  First := False;

                  Append (Result, """" & Ada.Strings.Fixed.Trim
                    (Events (Start .. Pos - 1), Ada.Strings.Both) & """");

                  Pos := Pos + 1;
               end loop;
            end;
            Append (Result, "]");
         end if;

         Append (Result, "}");
         return To_String (Result);
      end Build_JSON;

      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Build_JSON & "' " & API_URL;
   begin
      return Run_Curl (Args);
   end Update_Webhook;

   function Delete_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/hooks/" & Webhook_UUID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Webhook;

   ---------------------------------------------------------------------------
   --  Webhook Control
   ---------------------------------------------------------------------------

   function Enable_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result
   is
   begin
      return Update_Webhook (Creds, Repo_Name, Webhook_UUID, Active => "true");
   end Enable_Webhook;

   function Disable_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result
   is
   begin
      return Update_Webhook (Creds, Repo_Name, Webhook_UUID, Active => "false");
   end Disable_Webhook;

   function Test_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result
   is
      --  Bitbucket doesn't have a direct test endpoint, so we check webhook
      --  exists and is active
      Result : constant Webhook_Result :=
        Get_Webhook (Creds, Repo_Name, Webhook_UUID);
      Ret : Webhook_Result;
   begin
      if not Result.Success then
         return Result;
      end if;

      --  Check if active
      if Index (Result.Data, """active"": true") > 0 then
         Ret.Success := True;
         Ret.Message := To_Unbounded_String
           ("Webhook is active and configured");
         Ret.Data := Result.Data;
         Ret.Webhook_UUID := Result.Webhook_UUID;
      else
         Ret.Success := False;
         Ret.Message := To_Unbounded_String
           ("Webhook exists but is not active");
         Ret.Data := Result.Data;
         Ret.Webhook_UUID := Result.Webhook_UUID;
      end if;

      return Ret;
   end Test_Webhook;

   ---------------------------------------------------------------------------
   --  Workspace Webhooks
   ---------------------------------------------------------------------------

   function Create_Workspace_Webhook
     (Creds       : Config.Credentials;
      URL         : String;
      Description : String := "";
      Events      : Event_Set := Push_Events;
      Active      : Boolean := True) return Webhook_Result
   is
      API_URL : constant String := Base_URL & "/workspaces/" &
                                   To_String (Creds.Workspace) & "/hooks";

      Active_Str : constant String :=
        (if Active then "true" else "false");

      Desc_Field : constant String :=
        (if Description'Length > 0
         then """description"":""" & Escape_JSON (Description) & ""","
         else "");

      Data : constant String :=
        "{""url"":""" & URL & """," &
        Desc_Field &
        """active"":" & Active_Str & "," &
        """events"":" & Events_To_JSON (Events) & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & API_URL;
   begin
      return Run_Curl (Args);
   end Create_Workspace_Webhook;

   function List_Workspace_Webhooks
     (Creds : Config.Credentials) return Webhook_Result
   is
      URL : constant String := Base_URL & "/workspaces/" &
                               To_String (Creds.Workspace) & "/hooks";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Workspace_Webhooks;

   function Delete_Workspace_Webhook
     (Creds        : Config.Credentials;
      Webhook_UUID : String) return Webhook_Result
   is
      URL : constant String := Base_URL & "/workspaces/" &
                               To_String (Creds.Workspace) &
                               "/hooks/" & Webhook_UUID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Workspace_Webhook;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function Event_To_String (E : Webhook_Event) return String is
   begin
      case E is
         when Repo_Push                  => return "repo:push";
         when Repo_Fork                  => return "repo:fork";
         when Repo_Updated               => return "repo:updated";
         when Repo_Commit_Comment_Created => return "repo:commit_comment_created";
         when Repo_Commit_Status_Created => return "repo:commit_status_created";
         when Repo_Commit_Status_Updated => return "repo:commit_status_updated";
         when PR_Created                 => return "pullrequest:created";
         when PR_Updated                 => return "pullrequest:updated";
         when PR_Approved                => return "pullrequest:approved";
         when PR_Unapproved              => return "pullrequest:unapproved";
         when PR_Merged                  => return "pullrequest:fulfilled";
         when PR_Declined                => return "pullrequest:rejected";
         when PR_Comment_Created         => return "pullrequest:comment_created";
         when PR_Comment_Updated         => return "pullrequest:comment_updated";
         when PR_Comment_Deleted         => return "pullrequest:comment_deleted";
         when Issue_Created              => return "issue:created";
         when Issue_Updated              => return "issue:updated";
         when Issue_Comment_Created      => return "issue:comment_created";
      end case;
   end Event_To_String;

   function String_To_Event (S : String) return Webhook_Event is
      Lower : constant String := Ada.Characters.Handling.To_Lower (S);
   begin
      if Lower = "repo:push" then
         return Repo_Push;
      elsif Lower = "repo:fork" then
         return Repo_Fork;
      elsif Lower = "repo:updated" then
         return Repo_Updated;
      elsif Lower = "repo:commit_comment_created" then
         return Repo_Commit_Comment_Created;
      elsif Lower = "repo:commit_status_created" then
         return Repo_Commit_Status_Created;
      elsif Lower = "repo:commit_status_updated" then
         return Repo_Commit_Status_Updated;
      elsif Lower = "pullrequest:created" then
         return PR_Created;
      elsif Lower = "pullrequest:updated" then
         return PR_Updated;
      elsif Lower = "pullrequest:approved" then
         return PR_Approved;
      elsif Lower = "pullrequest:unapproved" then
         return PR_Unapproved;
      elsif Lower = "pullrequest:fulfilled" then
         return PR_Merged;
      elsif Lower = "pullrequest:rejected" then
         return PR_Declined;
      elsif Lower = "pullrequest:comment_created" then
         return PR_Comment_Created;
      elsif Lower = "pullrequest:comment_updated" then
         return PR_Comment_Updated;
      elsif Lower = "pullrequest:comment_deleted" then
         return PR_Comment_Deleted;
      elsif Lower = "issue:created" then
         return Issue_Created;
      elsif Lower = "issue:updated" then
         return Issue_Updated;
      elsif Lower = "issue:comment_created" then
         return Issue_Comment_Created;
      else
         return Repo_Push;  --  Default
      end if;
   end String_To_Event;

   function Events_To_JSON (Events : Event_Set) return String is
      Result : Unbounded_String := To_Unbounded_String ("[");
      First  : Boolean := True;
   begin
      for E in Webhook_Event'Range loop
         if Events (E) then
            if not First then
               Append (Result, ",");
            end if;
            First := False;
            Append (Result, """" & Event_To_String (E) & """");
         end if;
      end loop;

      Append (Result, "]");
      return To_String (Result);
   end Events_To_JSON;

   function Parse_Events_String (S : String) return Event_Set is
      Result : Event_Set := (others => False);
      Pos    : Natural := S'First;
      Start  : Natural;
   begin
      while Pos <= S'Last loop
         --  Skip whitespace and commas
         while Pos <= S'Last and then
               (S (Pos) = ' ' or S (Pos) = ',')
         loop
            Pos := Pos + 1;
         end loop;

         exit when Pos > S'Last;

         Start := Pos;

         --  Find end of event name
         while Pos <= S'Last and then S (Pos) /= ',' loop
            Pos := Pos + 1;
         end loop;

         --  Parse event
         declare
            Event_Str : constant String := Ada.Strings.Fixed.Trim
              (S (Start .. Pos - 1), Ada.Strings.Both);
         begin
            if Event_Str'Length > 0 then
               Result (String_To_Event (Event_Str)) := True;
            end if;
         end;
      end loop;

      return Result;
   end Parse_Events_String;

end Webhooks;
