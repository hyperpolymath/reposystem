-- SPDX-License-Identifier: PMPL-1.0
-- Team and permission management implementation

with GNAT.OS_Lib;
with GNAT.Expect;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;

package body Teams is

   Base_URL : constant String := "https://api.bitbucket.org/2.0";

   ---------------------------------------------------------------------------
   --  Internal: Execute curl command
   ---------------------------------------------------------------------------

   function Run_Curl (Args : String) return Team_Result is
      use GNAT.Expect;
      Pd     : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Ret    : Team_Result;
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

   function Workspace_URL (Creds : Config.Credentials) return String is
   begin
      return Base_URL & "/workspaces/" & To_String (Creds.Workspace);
   end Workspace_URL;

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
   --  Workspace Members
   ---------------------------------------------------------------------------

   function List_Members
     (Creds : Config.Credentials) return Team_Result
   is
      URL : constant String := Workspace_URL (Creds) & "/members";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Members;

   function Get_Member
     (Creds    : Config.Credentials;
      Username : String) return Team_Result
   is
      URL : constant String := Workspace_URL (Creds) &
                               "/members/" & Username;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Member;

   function Invite_Member
     (Creds    : Config.Credentials;
      Email    : String;
      Groups   : String := "") return Team_Result
   is
      URL : constant String := Workspace_URL (Creds) & "/invitations";

      Groups_Field : constant String :=
        (if Groups'Length > 0
         then ",""groups"":[""" & Groups & """]"
         else "");

      Data : constant String :=
        "{""email"":""" & Email & """" & Groups_Field & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Invite_Member;

   function Remove_Member
     (Creds    : Config.Credentials;
      Username : String) return Team_Result
   is
      URL : constant String := Workspace_URL (Creds) &
                               "/members/" & Username;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Remove_Member;

   ---------------------------------------------------------------------------
   --  User Groups
   ---------------------------------------------------------------------------

   function List_Groups
     (Creds : Config.Credentials) return Team_Result
   is
      URL : constant String := Workspace_URL (Creds) & "/permissions/groups";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Groups;

   function Create_Group
     (Creds       : Config.Credentials;
      Name        : String;
      Permission  : Permission_Level := Read;
      Auto_Add    : Boolean := False) return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace);

      Auto_Add_Str : constant String :=
        (if Auto_Add then "true" else "false");

      Data : constant String :=
        "{""name"":""" & Escape_JSON (Name) & """," &
        """permission"":""" & Permission_To_String (Permission) & """," &
        """auto_add"":" & Auto_Add_Str & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Group;

   function Get_Group
     (Creds      : Config.Credentials;
      Group_Slug : String) return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace) & "/" & Group_Slug;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Group;

   function Update_Group
     (Creds      : Config.Credentials;
      Group_Slug : String;
      Name       : String := "";
      Permission : String := "";
      Auto_Add   : String := "") return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace) & "/" & Group_Slug;

      function Build_JSON return String is
         Result    : Unbounded_String := To_Unbounded_String ("{");
         Has_Field : Boolean := False;

         procedure Add_Field (Field_Name, Value : String) is
         begin
            if Value'Length > 0 then
               if Has_Field then
                  Append (Result, ",");
               end if;
               Append (Result, """" & Field_Name & """:""" & Value & """");
               Has_Field := True;
            end if;
         end Add_Field;

         procedure Add_Bool_Field (Field_Name, Value : String) is
         begin
            if Value'Length > 0 then
               if Has_Field then
                  Append (Result, ",");
               end if;
               Append (Result, """" & Field_Name & """:" & Value);
               Has_Field := True;
            end if;
         end Add_Bool_Field;
      begin
         Add_Field ("name", Escape_JSON (Name));
         Add_Field ("permission", Permission);
         Add_Bool_Field ("auto_add", Auto_Add);
         Append (Result, "}");
         return To_String (Result);
      end Build_JSON;

      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Build_JSON & "' " & URL;
   begin
      return Run_Curl (Args);
   end Update_Group;

   function Delete_Group
     (Creds      : Config.Credentials;
      Group_Slug : String) return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace) & "/" & Group_Slug;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Group;

   function List_Group_Members
     (Creds      : Config.Credentials;
      Group_Slug : String) return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace) & "/" &
                               Group_Slug & "/members";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Group_Members;

   function Add_Group_Member
     (Creds      : Config.Credentials;
      Group_Slug : String;
      Username   : String) return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace) & "/" &
                               Group_Slug & "/members/" & Username;
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Add_Group_Member;

   function Remove_Group_Member
     (Creds      : Config.Credentials;
      Group_Slug : String;
      Username   : String) return Team_Result
   is
      URL : constant String := Base_URL & "/groups/" &
                               To_String (Creds.Workspace) & "/" &
                               Group_Slug & "/members/" & Username;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Remove_Group_Member;

   ---------------------------------------------------------------------------
   --  Repository Permissions
   ---------------------------------------------------------------------------

   function List_Repo_Permissions
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/permissions-config/users";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Repo_Permissions;

   function Get_User_Permission
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/permissions-config/users/" & Username;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_User_Permission;

   function Grant_User_Permission
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Username   : String;
      Permission : Permission_Level) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/permissions-config/users/" & Username;
      Data : constant String :=
        "{""permission"":""" & Permission_To_String (Permission) & """}";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Grant_User_Permission;

   function Revoke_User_Permission
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/permissions-config/users/" & Username;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Revoke_User_Permission;

   function Grant_Group_Permission
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Group_Slug : String;
      Permission : Permission_Level) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/permissions-config/groups/" & Group_Slug;
      Data : constant String :=
        "{""permission"":""" & Permission_To_String (Permission) & """}";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Grant_Group_Permission;

   function Revoke_Group_Permission
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Group_Slug : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/permissions-config/groups/" & Group_Slug;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Revoke_Group_Permission;

   ---------------------------------------------------------------------------
   --  Branch Restrictions
   ---------------------------------------------------------------------------

   function List_Branch_Restrictions
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/branch-restrictions";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Branch_Restrictions;

   function Create_Branch_Restriction
     (Creds            : Config.Credentials;
      Repo_Name        : String;
      Kind             : String;
      Branch_Match_Kind : String := "glob";
      Pattern          : String := "main";
      Users            : String := "";
      Groups           : String := "") return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/branch-restrictions";

      function Build_Users_Array return String is
         Result : Unbounded_String := To_Unbounded_String ("[");
         Pos    : Natural := Users'First;
         Start  : Natural;
         First  : Boolean := True;
      begin
         if Users'Length = 0 then
            return "[]";
         end if;

         while Pos <= Users'Last loop
            Start := Pos;
            while Pos <= Users'Last and then Users (Pos) /= ',' loop
               Pos := Pos + 1;
            end loop;

            if not First then
               Append (Result, ",");
            end if;
            First := False;

            Append (Result, "{""username"":""");
            Append (Result, Ada.Strings.Fixed.Trim
              (Users (Start .. Pos - 1), Ada.Strings.Both));
            Append (Result, """}");

            Pos := Pos + 1;
         end loop;

         Append (Result, "]");
         return To_String (Result);
      end Build_Users_Array;

      function Build_Groups_Array return String is
         Result : Unbounded_String := To_Unbounded_String ("[");
         Pos    : Natural := Groups'First;
         Start  : Natural;
         First  : Boolean := True;
      begin
         if Groups'Length = 0 then
            return "[]";
         end if;

         while Pos <= Groups'Last loop
            Start := Pos;
            while Pos <= Groups'Last and then Groups (Pos) /= ',' loop
               Pos := Pos + 1;
            end loop;

            if not First then
               Append (Result, ",");
            end if;
            First := False;

            Append (Result, "{""slug"":""");
            Append (Result, Ada.Strings.Fixed.Trim
              (Groups (Start .. Pos - 1), Ada.Strings.Both));
            Append (Result, """}");

            Pos := Pos + 1;
         end loop;

         Append (Result, "]");
         return To_String (Result);
      end Build_Groups_Array;

      Data : constant String :=
        "{""kind"":""" & Kind & """," &
        """branch_match_kind"":""" & Branch_Match_Kind & """," &
        """pattern"":""" & Pattern & """," &
        """users"":" & Build_Users_Array & "," &
        """groups"":" & Build_Groups_Array & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Branch_Restriction;

   function Delete_Branch_Restriction
     (Creds          : Config.Credentials;
      Repo_Name      : String;
      Restriction_ID : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/branch-restrictions/" & Restriction_ID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Branch_Restriction;

   ---------------------------------------------------------------------------
   --  Default Reviewers
   ---------------------------------------------------------------------------

   function List_Default_Reviewers
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/default-reviewers";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Default_Reviewers;

   function Add_Default_Reviewer
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/default-reviewers/" & Username;
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Add_Default_Reviewer;

   function Remove_Default_Reviewer
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/default-reviewers/" & Username;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Remove_Default_Reviewer;

   ---------------------------------------------------------------------------
   --  SSH Keys (Deploy Keys)
   ---------------------------------------------------------------------------

   function List_Deploy_Keys
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/deploy-keys";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Deploy_Keys;

   function Add_Deploy_Key
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Key       : String;
      Label     : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/deploy-keys";
      Data : constant String :=
        "{""key"":""" & Escape_JSON (Key) & """," &
        """label"":""" & Escape_JSON (Label) & """}";
      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Add_Deploy_Key;

   function Delete_Deploy_Key
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Key_ID    : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/deploy-keys/" & Key_ID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Deploy_Key;

   ---------------------------------------------------------------------------
   --  Access Tokens
   ---------------------------------------------------------------------------

   function List_Access_Tokens
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/access-tokens";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Access_Tokens;

   function Create_Access_Token
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      Name        : String;
      Scopes      : String;
      Expires_On  : String := "") return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/access-tokens";

      function Build_Scopes_Array return String is
         Result : Unbounded_String := To_Unbounded_String ("[");
         Pos    : Natural := Scopes'First;
         Start  : Natural;
         First  : Boolean := True;
      begin
         while Pos <= Scopes'Last loop
            Start := Pos;
            while Pos <= Scopes'Last and then Scopes (Pos) /= ',' loop
               Pos := Pos + 1;
            end loop;

            if not First then
               Append (Result, ",");
            end if;
            First := False;

            Append (Result, """");
            Append (Result, Ada.Strings.Fixed.Trim
              (Scopes (Start .. Pos - 1), Ada.Strings.Both));
            Append (Result, """");

            Pos := Pos + 1;
         end loop;

         Append (Result, "]");
         return To_String (Result);
      end Build_Scopes_Array;

      Expires_Field : constant String :=
        (if Expires_On'Length > 0
         then ",""expires_on"":""" & Expires_On & """"
         else "");

      Data : constant String :=
        "{""name"":""" & Escape_JSON (Name) & """," &
        """scopes"":" & Build_Scopes_Array &
        Expires_Field & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Access_Token;

   function Revoke_Access_Token
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Token_ID  : String) return Team_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/access-tokens/" & Token_ID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Revoke_Access_Token;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function Permission_To_String (P : Permission_Level) return String is
   begin
      case P is
         when Read  => return "read";
         when Write => return "write";
         when Admin => return "admin";
      end case;
   end Permission_To_String;

   function String_To_Permission (S : String) return Permission_Level is
      Lower : constant String := Ada.Characters.Handling.To_Lower (S);
   begin
      if Lower = "read" then
         return Read;
      elsif Lower = "write" then
         return Write;
      elsif Lower = "admin" then
         return Admin;
      else
         return Read;
      end if;
   end String_To_Permission;

   function Role_To_String (R : Workspace_Role) return String is
   begin
      case R is
         when Member       => return "member";
         when Collaborator => return "collaborator";
         when Owner        => return "owner";
      end case;
   end Role_To_String;

end Teams;
