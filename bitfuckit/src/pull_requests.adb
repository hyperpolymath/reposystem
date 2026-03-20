-- SPDX-License-Identifier: PMPL-1.0
-- Pull Request operations implementation

with GNAT.OS_Lib;
with GNAT.Expect;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;

package body Pull_Requests is

   Base_URL : constant String := "https://api.bitbucket.org/2.0";

   ---------------------------------------------------------------------------
   --  Internal: Execute curl command
   ---------------------------------------------------------------------------

   function Run_Curl (Args : String) return PR_Result is
      use GNAT.Expect;
      Pd     : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Ret    : PR_Result;
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

      --  Check for error response
      if Index (Output, """error""") > 0 or else
         Index (Output, """type"": ""error""") > 0
      then
         Ret.Success := False;
         Ret.Message := To_Unbounded_String ("API error in response");
      else
         Ret.Success := True;
         Ret.Message := To_Unbounded_String ("OK");
      end if;

      --  Extract PR ID if present
      declare
         ID_Pos : constant Natural := Index (Output, """id"": ");
      begin
         if ID_Pos > 0 then
            declare
               Start_Pos : constant Natural := ID_Pos + 6;
               End_Pos   : Natural := Start_Pos;
               Data_Str  : constant String := To_String (Output);
            begin
               while End_Pos <= Data_Str'Last and then
                     Data_Str (End_Pos) in '0' .. '9'
               loop
                  End_Pos := End_Pos + 1;
               end loop;
               if End_Pos > Start_Pos then
                  Ret.PR_ID := Natural'Value
                    (Data_Str (Start_Pos .. End_Pos - 1));
               end if;
            end;
         end if;
      end;

      --  Extract PR URL if present
      declare
         URL_Pos : constant Natural := Index (Output, """html"": {""href"": """);
      begin
         if URL_Pos > 0 then
            declare
               Start_Pos : constant Natural := URL_Pos + 18;
               End_Pos   : Natural := Index (Output, """", Start_Pos);
               Data_Str  : constant String := To_String (Output);
            begin
               if End_Pos > Start_Pos then
                  Ret.PR_URL := To_Unbounded_String
                    (Data_Str (Start_Pos .. End_Pos - 1));
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

   ---------------------------------------------------------------------------
   --  Internal: Build authentication string
   ---------------------------------------------------------------------------

   function Auth_String (Creds : Config.Credentials) return String is
   begin
      return "-u " & To_String (Creds.Username) & ":" &
             To_String (Creds.App_Password);
   end Auth_String;

   ---------------------------------------------------------------------------
   --  Internal: Build repository URL base
   ---------------------------------------------------------------------------

   function Repo_URL
     (Creds     : Config.Credentials;
      Repo_Name : String) return String
   is
   begin
      return Base_URL & "/repositories/" &
             To_String (Creds.Workspace) & "/" & Repo_Name;
   end Repo_URL;

   ---------------------------------------------------------------------------
   --  Internal: Escape JSON string
   ---------------------------------------------------------------------------

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
   --  PR Creation
   ---------------------------------------------------------------------------

   function Create_PR
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Title         : String;
      Source_Branch : String;
      Dest_Branch   : String := "main";
      Description   : String := "";
      Reviewers     : String := "";
      Close_Source  : Boolean := False) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/pullrequests";

      --  Build reviewers JSON array
      function Build_Reviewers return String is
         Result : Unbounded_String := To_Unbounded_String ("[");
         Pos    : Natural := Reviewers'First;
         Start  : Natural;
         First  : Boolean := True;
      begin
         if Reviewers'Length = 0 then
            return "[]";
         end if;

         while Pos <= Reviewers'Last loop
            Start := Pos;
            while Pos <= Reviewers'Last and then Reviewers (Pos) /= ',' loop
               Pos := Pos + 1;
            end loop;

            if not First then
               Append (Result, ",");
            end if;
            First := False;

            Append (Result, "{""username"":""");
            Append (Result, Ada.Strings.Fixed.Trim
              (Reviewers (Start .. Pos - 1), Ada.Strings.Both));
            Append (Result, """}");

            Pos := Pos + 1;  --  Skip comma
         end loop;

         Append (Result, "]");
         return To_String (Result);
      end Build_Reviewers;

      Close_Str : constant String :=
        (if Close_Source then "true" else "false");

      Data : constant String :=
        "{""title"":""" & Escape_JSON (Title) & """," &
        """source"":{""branch"":{""name"":""" & Source_Branch & """}}," &
        """destination"":{""branch"":{""name"":""" & Dest_Branch & """}}," &
        """description"":""" & Escape_JSON (Description) & """," &
        """reviewers"":" & Build_Reviewers & "," &
        """close_source_branch"":" & Close_Str & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_PR;

   ---------------------------------------------------------------------------
   --  PR Viewing
   ---------------------------------------------------------------------------

   function Get_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL  : constant String := Repo_URL (Creds, Repo_Name) &
                                "/pullrequests/" & Ada.Strings.Fixed.Trim
                                  (Positive'Image (PR_ID), Ada.Strings.Left);
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_PR;

   function List_PRs
     (Creds     : Config.Credentials;
      Repo_Name : String;
      State     : PR_State := Open;
      Author    : String := "";
      Page_Len  : Positive := 25) return PR_Result
   is
      State_Param : constant String := "&state=" & State_To_String (State);
      Author_Param : constant String :=
        (if Author'Length > 0
         then "&q=author.username=""" & Author & """"
         else "");

      URL : constant String :=
        Repo_URL (Creds, Repo_Name) & "/pullrequests?pagelen=" &
        Ada.Strings.Fixed.Trim (Positive'Image (Page_Len), Ada.Strings.Left) &
        State_Param & Author_Param;

      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_PRs;

   function Get_PR_Diff
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/diff";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_PR_Diff;

   function Get_PR_Commits
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/commits";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_PR_Commits;

   ---------------------------------------------------------------------------
   --  PR Actions
   ---------------------------------------------------------------------------

   function Merge_PR
     (Creds          : Config.Credentials;
      Repo_Name      : String;
      PR_ID          : Positive;
      Strategy       : Merge_Strategy := Merge_Commit;
      Message        : String := "";
      Close_Source   : Boolean := True) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/merge";

      Close_Str : constant String :=
        (if Close_Source then "true" else "false");

      Message_Field : constant String :=
        (if Message'Length > 0
         then """message"":""" & Escape_JSON (Message) & ""","
         else "");

      Data : constant String :=
        "{" & Message_Field &
        """merge_strategy"":""" & Strategy_To_String (Strategy) & """," &
        """close_source_branch"":" & Close_Str & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Merge_PR;

   function Decline_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      Reason    : String := "") return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/decline";

      Data : constant String :=
        (if Reason'Length > 0
         then "{""reason"":""" & Escape_JSON (Reason) & """}"
         else "{}");

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Decline_PR;

   function Update_PR
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      PR_ID       : Positive;
      Title       : String := "";
      Description : String := "";
      Dest_Branch : String := "") return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left);

      --  Build JSON with only non-empty fields
      function Build_Update_JSON return String is
         Result : Unbounded_String := To_Unbounded_String ("{");
         Has_Field : Boolean := False;
      begin
         if Title'Length > 0 then
            Append (Result, """title"":""" & Escape_JSON (Title) & """");
            Has_Field := True;
         end if;

         if Description'Length > 0 then
            if Has_Field then
               Append (Result, ",");
            end if;
            Append (Result, """description"":""" &
                    Escape_JSON (Description) & """");
            Has_Field := True;
         end if;

         if Dest_Branch'Length > 0 then
            if Has_Field then
               Append (Result, ",");
            end if;
            Append (Result, """destination"":{""branch"":{""name"":""" &
                    Dest_Branch & """}}");
         end if;

         Append (Result, "}");
         return To_String (Result);
      end Build_Update_JSON;

      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Build_Update_JSON & "' " & URL;
   begin
      return Run_Curl (Args);
   end Update_PR;

   ---------------------------------------------------------------------------
   --  PR Reviews
   ---------------------------------------------------------------------------

   function Approve_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/approve";
      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Approve_PR;

   function Unapprove_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/approve";
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Unapprove_PR;

   function Request_Changes
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      Comment   : String) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/request-changes";

      Data : constant String :=
        "{""content"":{""raw"":""" & Escape_JSON (Comment) & """}}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Request_Changes;

   function Get_Approvals
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      --  Approvals are part of the PR response, in the "participants" field
      Result : PR_Result := Get_PR (Creds, Repo_Name, PR_ID);
   begin
      --  The full PR data contains participants with their approval status
      return Result;
   end Get_Approvals;

   ---------------------------------------------------------------------------
   --  PR Comments
   ---------------------------------------------------------------------------

   function Add_Comment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      Content   : String) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/comments";

      Data : constant String :=
        "{""content"":{""raw"":""" & Escape_JSON (Content) & """}}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Add_Comment;

   function Add_Inline_Comment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      File_Path : String;
      Line      : Positive;
      Content   : String) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/comments";

      Line_Str : constant String := Ada.Strings.Fixed.Trim
                                      (Positive'Image (Line), Ada.Strings.Left);

      Data : constant String :=
        "{""content"":{""raw"":""" & Escape_JSON (Content) & """}," &
        """inline"":{""path"":""" & File_Path & """," &
        """to"":" & Line_Str & "}}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Add_Inline_Comment;

   function List_Comments
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/comments?pagelen=100";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Comments;

   function Delete_Comment
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      PR_ID      : Positive;
      Comment_ID : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/comments/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (Comment_ID), Ada.Strings.Left);
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Comment;

   ---------------------------------------------------------------------------
   --  PR Status
   ---------------------------------------------------------------------------

   function Get_Build_Status
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pullrequests/" & Ada.Strings.Fixed.Trim
                                 (Positive'Image (PR_ID), Ada.Strings.Left) &
                               "/statuses";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Build_Status;

   function Can_Merge
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return Boolean
   is
      Result : constant PR_Result := Get_PR (Creds, Repo_Name, PR_ID);
   begin
      if not Result.Success then
         return False;
      end if;

      --  Check for merge conflicts indicator in response
      --  PR is mergeable if state is OPEN and no conflicts
      return Index (Result.Data, """state"": ""OPEN""") > 0 and then
             Index (Result.Data, """has_conflicts"": true") = 0;
   end Can_Merge;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function State_To_String (S : PR_State) return String is
   begin
      case S is
         when Open       => return "OPEN";
         when Merged     => return "MERGED";
         when Declined   => return "DECLINED";
         when Superseded => return "SUPERSEDED";
      end case;
   end State_To_String;

   function String_To_State (S : String) return PR_State is
      Upper : constant String := Ada.Characters.Handling.To_Upper (S);
   begin
      if Upper = "OPEN" then
         return Open;
      elsif Upper = "MERGED" then
         return Merged;
      elsif Upper = "DECLINED" then
         return Declined;
      elsif Upper = "SUPERSEDED" then
         return Superseded;
      else
         return Open;  --  Default
      end if;
   end String_To_State;

   function Strategy_To_String (S : Merge_Strategy) return String is
   begin
      case S is
         when Merge_Commit => return "merge_commit";
         when Squash       => return "squash";
         when Fast_Forward => return "fast_forward";
      end case;
   end Strategy_To_String;

end Pull_Requests;
