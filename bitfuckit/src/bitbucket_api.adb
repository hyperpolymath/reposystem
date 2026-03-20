-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

with GNAT.OS_Lib;
with GNAT.Expect;
with Ada.Text_IO;
with Ada.Strings;
with Ada.Strings.Fixed; use Ada.Strings.Fixed;
with Ada.Characters.Latin_1;

package body Bitbucket_API is

   Base_URL : constant String := "https://api.bitbucket.org/2.0";

   function Run_Curl
     (Args : String) return API_Result
   is
      use GNAT.Expect;
      Pd : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Ret : API_Result;
   begin
      Non_Blocking_Spawn
        (Pd,
         "/usr/bin/curl",
         GNAT.OS_Lib.Argument_String_To_List (Args).all,
         Err_To_Out => True);

      loop
         begin
            Expect (Pd, Result, ".+", Timeout => 30_000);
            Append (Output, Expect_Out (Pd));
         exception
            when Process_Died =>
               exit;
         end;
      end loop;

      Close (Pd);

      Ret.Data := Output;

      --  Extract HTTP status code from -w output (appended as __HTTP_STATUS:NNN)
      declare
         Status_Marker : constant String := "__HTTP_STATUS:";
         Marker_Pos    : constant Natural := Index (Output, Status_Marker);
         HTTP_Status   : Natural := 0;
         Resp_Body          : Unbounded_String := Output;
      begin
         if Marker_Pos > 0 then
            --  Parse the 3-digit status code after the marker
            declare
               Code_Str : constant String :=
                  Slice (Output, Marker_Pos + Status_Marker'Length,
                         Length (Output));
            begin
               HTTP_Status := Natural'Value (Trim (Code_Str, Ada.Strings.Both));
            exception
               when others => HTTP_Status := 0;
            end;
            --  Strip the status marker from the body
            Resp_Body := Head (Output, Marker_Pos - 1);
            --  Also strip trailing newline before marker
            if Length (Resp_Body) > 0
              and then Element (Resp_Body, Length (Resp_Body)) = Ada.Characters.Latin_1.LF
            then
               Resp_Body := Head (Resp_Body, Length (Resp_Body) - 1);
            end if;
         end if;

         Ret.Data := Resp_Body;

         --  Check for failure conditions:
         --  1. Non-2xx HTTP status
         --  2. Empty response body
         --  3. Explicit "error" field in JSON response
         if HTTP_Status >= 400 then
            Ret.Success := False;
            Ret.Message := To_Unbounded_String
              ("HTTP " & Natural'Image (HTTP_Status) &
               (if HTTP_Status = 401 then
                  " Unauthorized — API token expired or invalid. " &
                  "Generate a new token at " &
                  "https://id.atlassian.com/manage-profile/security/api-tokens"
                elsif HTTP_Status = 403 then
                  " Forbidden — token lacks required scopes"
                elsif HTTP_Status = 404 then
                  " Not Found — workspace or repo does not exist"
                else
                  " — " & To_String (Resp_Body)));
         elsif Length (Resp_Body) = 0 and HTTP_Status = 0 then
            Ret.Success := False;
            Ret.Message := To_Unbounded_String
              ("Empty response — network error or API unreachable");
         elsif Index (Resp_Body, """error""") > 0
           or Index (Resp_Body, """type"": ""error""") > 0
         then
            Ret.Success := False;
            Ret.Message := To_Unbounded_String
              ("API error: " & To_String (Resp_Body));
         else
            Ret.Success := True;
            Ret.Message := To_Unbounded_String ("OK");
         end if;
      end;

      return Ret;

   exception
      when others =>
         Ret.Success := False;
         Ret.Message := To_Unbounded_String ("Failed to execute curl");
         return Ret;
   end Run_Curl;

   function Create_Repo
     (Creds : Config.Credentials;
      Name : String;
      Is_Private : Boolean := False;
      Description : String := "") return API_Result
   is
      URL : constant String :=
         Base_URL & "/repositories/" &
         To_String (Creds.Workspace) & "/" & Name;
      Private_Str : constant String :=
         (if Is_Private then "true" else "false");
      Data : constant String :=
         "{""scm"":""git"",""is_private"":" & Private_Str &
         ",""description"":""" & Description & """}";
      Args : constant String :=
         "-s -w ""\n__HTTP_STATUS:%{http_code}"" -X POST " &
         "-u " & To_String (Creds.Username) & ":" &
         To_String (Creds.App_Password) & " " &
         "-H ""Content-Type: application/json"" " &
         "-d '" & Data & "' " &
         URL;
   begin
      return Run_Curl (Args);
   end Create_Repo;

   function Delete_Repo
     (Creds : Config.Credentials;
      Name : String) return API_Result
   is
      URL : constant String :=
         Base_URL & "/repositories/" &
         To_String (Creds.Workspace) & "/" & Name;
      Args : constant String :=
         "-s -w ""\n__HTTP_STATUS:%{http_code}"" -X DELETE " &
         "-u " & To_String (Creds.Username) & ":" &
         To_String (Creds.App_Password) & " " &
         URL;
   begin
      return Run_Curl (Args);
   end Delete_Repo;

   function List_Repos
     (Creds : Config.Credentials) return API_Result
   is
      URL : constant String :=
         Base_URL & "/repositories/" &
         To_String (Creds.Workspace) & "?pagelen=100";
      Args : constant String :=
         "-s -w ""\n__HTTP_STATUS:%{http_code}"" -X GET " &
         "-u " & To_String (Creds.Username) & ":" &
         To_String (Creds.App_Password) & " " &
         URL;
   begin
      return Run_Curl (Args);
   end List_Repos;

   function Get_Repo
     (Creds : Config.Credentials;
      Name : String) return API_Result
   is
      URL : constant String :=
         Base_URL & "/repositories/" &
         To_String (Creds.Workspace) & "/" & Name;
      Args : constant String :=
         "-s -w ""\n__HTTP_STATUS:%{http_code}"" -X GET " &
         "-u " & To_String (Creds.Username) & ":" &
         To_String (Creds.App_Password) & " " &
         URL;
   begin
      return Run_Curl (Args);
   end Get_Repo;

   function Repo_Exists
     (Creds : Config.Credentials;
      Name : String) return Boolean
   is
      Result : constant API_Result := Get_Repo (Creds, Name);
   begin
      return Result.Success and then
         Index (Result.Data, """slug"":""" & Name & """") > 0;
   end Repo_Exists;

   function List_Pull_Requests
     (Creds : Config.Credentials;
      Repo_Name : String;
      State : String := "OPEN") return API_Result
   is
      State_Param : constant String :=
         (if State'Length > 0
          then "&state=" & State
          else "");
      URL : constant String :=
         Base_URL & "/repositories/" &
         To_String (Creds.Workspace) & "/" & Repo_Name &
         "/pullrequests?pagelen=50" & State_Param;
      Args : constant String :=
         "-s -w ""\n__HTTP_STATUS:%{http_code}"" -X GET " &
         "-u " & To_String (Creds.Username) & ":" &
         To_String (Creds.App_Password) & " " &
         URL;
   begin
      return Run_Curl (Args);
   end List_Pull_Requests;

end Bitbucket_API;
