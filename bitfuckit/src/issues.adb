-- SPDX-License-Identifier: PMPL-1.0
-- Issue tracking operations implementation

with GNAT.OS_Lib;
with GNAT.Expect;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;

package body Issues is

   Base_URL : constant String := "https://api.bitbucket.org/2.0";

   ---------------------------------------------------------------------------
   --  Internal: Execute curl command
   ---------------------------------------------------------------------------

   function Run_Curl (Args : String) return Issue_Result is
      use GNAT.Expect;
      Pd     : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Ret    : Issue_Result;
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

      --  Extract Issue ID if present
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
                  Ret.Issue_ID := Natural'Value
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
   --  Issue CRUD
   ---------------------------------------------------------------------------

   function Create_Issue
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      Title       : String;
      Content     : String := "";
      Kind        : Issue_Kind := Bug;
      Priority    : Issue_Priority := Major;
      Assignee    : String := "";
      Component   : String := "";
      Milestone   : String := "";
      Version     : String := "") return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues";

      function Build_JSON return String is
         Result : Unbounded_String := To_Unbounded_String
           ("{""title"":""" & Escape_JSON (Title) & """");
      begin
         if Content'Length > 0 then
            Append (Result, ",""content"":{""raw"":""" &
                    Escape_JSON (Content) & """}");
         end if;

         Append (Result, ",""kind"":""" & Kind_To_String (Kind) & """");
         Append (Result, ",""priority"":""" & Priority_To_String (Priority) & """");

         if Assignee'Length > 0 then
            Append (Result, ",""assignee"":{""username"":""" & Assignee & """}");
         end if;

         if Component'Length > 0 then
            Append (Result, ",""component"":{""name"":""" & Component & """}");
         end if;

         if Milestone'Length > 0 then
            Append (Result, ",""milestone"":{""name"":""" & Milestone & """}");
         end if;

         if Version'Length > 0 then
            Append (Result, ",""version"":{""name"":""" & Version & """}");
         end if;

         Append (Result, "}");
         return To_String (Result);
      end Build_JSON;

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Build_JSON & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Issue;

   function Get_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left);
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Issue;

   function Update_Issue
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      Issue_ID    : Positive;
      Title       : String := "";
      Content     : String := "";
      State       : String := "";
      Kind        : String := "";
      Priority    : String := "";
      Assignee    : String := "";
      Component   : String := "";
      Milestone   : String := "";
      Version     : String := "") return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left);

      function Build_JSON return String is
         Result    : Unbounded_String := To_Unbounded_String ("{");
         Has_Field : Boolean := False;

         procedure Add_Field (Name, Value : String) is
         begin
            if Value'Length > 0 then
               if Has_Field then
                  Append (Result, ",");
               end if;
               Append (Result, """" & Name & """:""" & Value & """");
               Has_Field := True;
            end if;
         end Add_Field;

         procedure Add_Object_Field (Name, Inner_Name, Value : String) is
         begin
            if Value'Length > 0 then
               if Has_Field then
                  Append (Result, ",");
               end if;
               Append (Result, """" & Name & """:{""" &
                       Inner_Name & """:""" & Value & """}");
               Has_Field := True;
            end if;
         end Add_Object_Field;
      begin
         Add_Field ("title", Escape_JSON (Title));
         Add_Field ("state", State);
         Add_Field ("kind", Kind);
         Add_Field ("priority", Priority);

         if Content'Length > 0 then
            if Has_Field then
               Append (Result, ",");
            end if;
            Append (Result, """content"":{""raw"":""" &
                    Escape_JSON (Content) & """}");
            Has_Field := True;
         end if;

         Add_Object_Field ("assignee", "username", Assignee);
         Add_Object_Field ("component", "name", Component);
         Add_Object_Field ("milestone", "name", Milestone);
         Add_Object_Field ("version", "name", Version);

         Append (Result, "}");
         return To_String (Result);
      end Build_JSON;

      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Build_JSON & "' " & URL;
   begin
      return Run_Curl (Args);
   end Update_Issue;

   function Delete_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left);
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Issue;

   ---------------------------------------------------------------------------
   --  Issue Listing
   ---------------------------------------------------------------------------

   function List_Issues
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      State      : String := "";
      Kind       : String := "";
      Priority   : String := "";
      Assignee   : String := "";
      Reporter   : String := "";
      Component  : String := "";
      Milestone  : String := "";
      Search     : String := "";
      Sort       : String := "-created_on";
      Page_Len   : Positive := 25) return Issue_Result
   is
      function Build_Query return String is
         Result : Unbounded_String := Null_Unbounded_String;
         Parts  : Natural := 0;

         procedure Add_Filter (Field, Value : String) is
         begin
            if Value'Length > 0 then
               if Parts > 0 then
                  Append (Result, " AND ");
               end if;
               Append (Result, Field & "=""" & Value & """");
               Parts := Parts + 1;
            end if;
         end Add_Filter;
      begin
         Add_Filter ("state", State);
         Add_Filter ("kind", Kind);
         Add_Filter ("priority", Priority);
         Add_Filter ("assignee.username", Assignee);
         Add_Filter ("reporter.username", Reporter);
         Add_Filter ("component.name", Component);
         Add_Filter ("milestone.name", Milestone);

         if Search'Length > 0 then
            if Parts > 0 then
               Append (Result, " AND ");
            end if;
            Append (Result, "title ~ """ & Search & """");
         end if;

         return To_String (Result);
      end Build_Query;

      Query_Str : constant String := Build_Query;
      Query_Param : constant String :=
        (if Query_Str'Length > 0
         then "&q=" & Query_Str
         else "");

      URL : constant String :=
        Repo_URL (Creds, Repo_Name) & "/issues?pagelen=" &
        Ada.Strings.Fixed.Trim (Positive'Image (Page_Len), Ada.Strings.Left) &
        "&sort=" & Sort & Query_Param;

      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Issues;

   ---------------------------------------------------------------------------
   --  Issue Comments
   ---------------------------------------------------------------------------

   function Add_Comment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive;
      Content   : String) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
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

   function List_Comments
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/comments?pagelen=100";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Comments;

   function Update_Comment
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Issue_ID   : Positive;
      Comment_ID : Positive;
      Content    : String) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/comments/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Comment_ID), Ada.Strings.Left);
      Data : constant String :=
        "{""content"":{""raw"":""" & Escape_JSON (Content) & """}}";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Update_Comment;

   function Delete_Comment
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Issue_ID   : Positive;
      Comment_ID : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/comments/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Comment_ID), Ada.Strings.Left);
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Comment;

   ---------------------------------------------------------------------------
   --  Issue Attachments
   ---------------------------------------------------------------------------

   function Add_Attachment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive;
      File_Path : String) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/attachments";
      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-F ""files=@" & File_Path & """ " & URL;
   begin
      return Run_Curl (Args);
   end Add_Attachment;

   function List_Attachments
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/attachments";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Attachments;

   function Delete_Attachment
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Issue_ID      : Positive;
      Attachment_ID : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/attachments/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Attachment_ID), Ada.Strings.Left);
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Attachment;

   ---------------------------------------------------------------------------
   --  Issue Watch/Vote
   ---------------------------------------------------------------------------

   function Watch_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/watch";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Watch_Issue;

   function Unwatch_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/watch";
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Unwatch_Issue;

   function Vote_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/vote";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Vote_Issue;

   function Unvote_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/vote";
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Unvote_Issue;

   ---------------------------------------------------------------------------
   --  Issue Changes/History
   ---------------------------------------------------------------------------

   function Get_Changes
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/issues/" &
                               Ada.Strings.Fixed.Trim
                                 (Positive'Image (Issue_ID), Ada.Strings.Left) &
                               "/changes";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Changes;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function State_To_String (S : Issue_State) return String is
   begin
      case S is
         when Open_Issue => return "open";
         when New_Issue  => return "new";
         when On_Hold    => return "on hold";
         when Resolved   => return "resolved";
         when Duplicate  => return "duplicate";
         when Invalid    => return "invalid";
         when Wontfix    => return "wontfix";
         when Closed     => return "closed";
      end case;
   end State_To_String;

   function String_To_State (S : String) return Issue_State is
      Lower : constant String := Ada.Characters.Handling.To_Lower (S);
   begin
      if Lower = "open" then
         return Open_Issue;
      elsif Lower = "new" then
         return New_Issue;
      elsif Lower = "on hold" then
         return On_Hold;
      elsif Lower = "resolved" then
         return Resolved;
      elsif Lower = "duplicate" then
         return Duplicate;
      elsif Lower = "invalid" then
         return Invalid;
      elsif Lower = "wontfix" then
         return Wontfix;
      elsif Lower = "closed" then
         return Closed;
      else
         return Open_Issue;
      end if;
   end String_To_State;

   function Priority_To_String (P : Issue_Priority) return String is
   begin
      case P is
         when Trivial  => return "trivial";
         when Minor    => return "minor";
         when Major    => return "major";
         when Critical => return "critical";
         when Blocker  => return "blocker";
      end case;
   end Priority_To_String;

   function String_To_Priority (S : String) return Issue_Priority is
      Lower : constant String := Ada.Characters.Handling.To_Lower (S);
   begin
      if Lower = "trivial" then
         return Trivial;
      elsif Lower = "minor" then
         return Minor;
      elsif Lower = "major" then
         return Major;
      elsif Lower = "critical" then
         return Critical;
      elsif Lower = "blocker" then
         return Blocker;
      else
         return Major;
      end if;
   end String_To_Priority;

   function Kind_To_String (K : Issue_Kind) return String is
   begin
      case K is
         when Bug         => return "bug";
         when Enhancement => return "enhancement";
         when Proposal    => return "proposal";
         when Task_Item   => return "task";
      end case;
   end Kind_To_String;

   function String_To_Kind (S : String) return Issue_Kind is
      Lower : constant String := Ada.Characters.Handling.To_Lower (S);
   begin
      if Lower = "bug" then
         return Bug;
      elsif Lower = "enhancement" then
         return Enhancement;
      elsif Lower = "proposal" then
         return Proposal;
      elsif Lower = "task" then
         return Task_Item;
      else
         return Bug;
      end if;
   end String_To_Kind;

end Issues;
