-- SPDX-License-Identifier: PMPL-1.0
-- Bitbucket Pipelines implementation

with GNAT.OS_Lib;
with GNAT.Expect;
with Ada.Strings.Fixed;
with Ada.Characters.Handling;

package body Pipelines is

   Base_URL : constant String := "https://api.bitbucket.org/2.0";

   ---------------------------------------------------------------------------
   --  Internal: Execute curl command
   ---------------------------------------------------------------------------

   function Run_Curl (Args : String) return Pipeline_Result is
      use GNAT.Expect;
      Pd     : Process_Descriptor;
      Result : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Ret    : Pipeline_Result;
   begin
      Non_Blocking_Spawn
        (Pd,
         "/usr/bin/curl",
         GNAT.OS_Lib.Argument_String_To_List (Args).all,
         Err_To_Out => True);

      loop
         begin
            Expect (Pd, Result, ".+", Timeout => 120_000);
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
                  Ret.Pipeline_UUID := To_Unbounded_String
                    ("{" & Data_Str (Start_Pos .. End_Pos) & "}");
               end if;
            end;
         end if;
      end;

      --  Extract build number if present
      declare
         BN_Pos : constant Natural := Index (Output, """build_number"": ");
      begin
         if BN_Pos > 0 then
            declare
               Start_Pos : constant Natural := BN_Pos + 16;
               End_Pos   : Natural := Start_Pos;
               Data_Str  : constant String := To_String (Output);
            begin
               while End_Pos <= Data_Str'Last and then
                     Data_Str (End_Pos) in '0' .. '9'
               loop
                  End_Pos := End_Pos + 1;
               end loop;
               if End_Pos > Start_Pos then
                  Ret.Build_Number := Natural'Value
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
   --  Pipeline Configuration
   ---------------------------------------------------------------------------

   function Get_Config
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/src/HEAD/bitbucket-pipelines.yml";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Config;

   function Update_Config
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Content   : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/src";
      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-F ""bitbucket-pipelines.yml=" & Content & """ " &
        "-F ""message=Update pipeline configuration"" " & URL;
   begin
      return Run_Curl (Args);
   end Update_Config;

   function Is_Enabled
     (Creds     : Config.Credentials;
      Repo_Name : String) return Boolean
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
      Result : constant Pipeline_Result := Run_Curl (Args);
   begin
      return Result.Success and then
             Index (Result.Data, """enabled"": true") > 0;
   end Is_Enabled;

   function Enable_Pipelines
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config";
      Data : constant String := "{""enabled"": true}";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Enable_Pipelines;

   function Disable_Pipelines
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config";
      Data : constant String := "{""enabled"": false}";
      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Disable_Pipelines;

   ---------------------------------------------------------------------------
   --  Pipeline Listing
   ---------------------------------------------------------------------------

   function List_Pipelines
     (Creds     : Config.Credentials;
      Repo_Name : String;
      State     : String := "";
      Target_Branch : String := "";
      Page_Len  : Positive := 25) return Pipeline_Result
   is
      State_Param : constant String :=
        (if State'Length > 0
         then "&state.result.name=" & State
         else "");

      Branch_Param : constant String :=
        (if Target_Branch'Length > 0
         then "&target.ref_name=" & Target_Branch
         else "");

      URL : constant String :=
        Repo_URL (Creds, Repo_Name) & "/pipelines/?pagelen=" &
        Ada.Strings.Fixed.Trim (Positive'Image (Page_Len), Ada.Strings.Left) &
        "&sort=-created_on" & State_Param & Branch_Param;

      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Pipelines;

   function Get_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines/" & Pipeline_UUID;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Pipeline;

   function Get_Latest_Pipeline
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Branch    : String := "") return Pipeline_Result
   is
   begin
      return List_Pipelines (Creds, Repo_Name,
                             Target_Branch => Branch,
                             Page_Len => 1);
   end Get_Latest_Pipeline;

   ---------------------------------------------------------------------------
   --  Pipeline Triggers
   ---------------------------------------------------------------------------

   function Trigger_Pipeline
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Target    : String;
      Variables : String := "") return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/pipelines/";

      Vars_Field : constant String :=
        (if Variables'Length > 0
         then ",""variables"":" & Variables
         else "");

      Data : constant String :=
        "{""target"":{""ref_type"":""branch""," &
        """type"":""pipeline_ref_target""," &
        """ref_name"":""" & Target & """}" & Vars_Field & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Trigger_Pipeline;

   function Trigger_Custom_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Target        : String;
      Pipeline_Name : String;
      Variables     : String := "") return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/pipelines/";

      Vars_Field : constant String :=
        (if Variables'Length > 0
         then ",""variables"":" & Variables
         else "");

      Data : constant String :=
        "{""target"":{""ref_type"":""branch""," &
        """type"":""pipeline_ref_target""," &
        """ref_name"":""" & Target & """," &
        """selector"":{""type"":""custom""," &
        """pattern"":""" & Pipeline_Name & """}}" & Vars_Field & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Trigger_Custom_Pipeline;

   function Trigger_PR_Pipeline
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/pipelines/";

      Data : constant String :=
        "{""target"":{""type"":""pipeline_pullrequest_target""," &
        """source"":""pullrequests/" &
        Ada.Strings.Fixed.Trim (Positive'Image (PR_ID), Ada.Strings.Left) &
        """}}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Trigger_PR_Pipeline;

   ---------------------------------------------------------------------------
   --  Pipeline Control
   ---------------------------------------------------------------------------

   function Stop_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines/" & Pipeline_UUID & "/stopPipeline";
      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Stop_Pipeline;

   function Rerun_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result
   is
      --  Get original pipeline to retrieve target info
      Original : constant Pipeline_Result :=
        Get_Pipeline (Creds, Repo_Name, Pipeline_UUID);
   begin
      if not Original.Success then
         return Original;
      end if;

      --  Extract target branch from original and trigger new pipeline
      --  For simplicity, we'll just trigger on the same reference
      declare
         Ref_Pos : constant Natural := Index (Original.Data, """ref_name"": """);
         Ref_Name : Unbounded_String := To_Unbounded_String ("main");
      begin
         if Ref_Pos > 0 then
            declare
               Start_Pos : constant Natural := Ref_Pos + 13;
               End_Pos   : constant Natural := Index (Original.Data, """", Start_Pos);
               Data_Str  : constant String := To_String (Original.Data);
            begin
               if End_Pos > Start_Pos then
                  Ref_Name := To_Unbounded_String
                    (Data_Str (Start_Pos .. End_Pos - 1));
               end if;
            end;
         end if;

         return Trigger_Pipeline (Creds, Repo_Name, To_String (Ref_Name));
      end;
   end Rerun_Pipeline;

   ---------------------------------------------------------------------------
   --  Pipeline Steps
   ---------------------------------------------------------------------------

   function List_Steps
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines/" & Pipeline_UUID & "/steps/";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Steps;

   function Get_Step
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String;
      Step_UUID     : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines/" & Pipeline_UUID &
                               "/steps/" & Step_UUID;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Step;

   function Get_Step_Log
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String;
      Step_UUID     : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines/" & Pipeline_UUID &
                               "/steps/" & Step_UUID & "/log";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " &
        "-H ""Accept: application/octet-stream"" " & URL;
   begin
      return Run_Curl (Args);
   end Get_Step_Log;

   ---------------------------------------------------------------------------
   --  Pipeline Variables
   ---------------------------------------------------------------------------

   function List_Variables
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/variables/";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Variables;

   function Create_Variable
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Key       : String;
      Value     : String;
      Secured   : Boolean := False) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/variables/";

      Secured_Str : constant String :=
        (if Secured then "true" else "false");

      Data : constant String :=
        "{""key"":""" & Key & """," &
        """value"":""" & Escape_JSON (Value) & """," &
        """secured"":" & Secured_Str & "}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Variable;

   function Update_Variable
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Var_UUID  : String;
      Value     : String;
      Secured   : Boolean := False) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/variables/" & Var_UUID;

      Secured_Str : constant String :=
        (if Secured then "true" else "false");

      Data : constant String :=
        "{""value"":""" & Escape_JSON (Value) & """," &
        """secured"":" & Secured_Str & "}";

      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Update_Variable;

   function Delete_Variable
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Var_UUID  : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/variables/" & Var_UUID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Variable;

   ---------------------------------------------------------------------------
   --  Deployment Environments
   ---------------------------------------------------------------------------

   function List_Environments
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/environments/";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Environments;

   function Get_Environment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Env_UUID  : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/environments/" & Env_UUID;
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Get_Environment;

   function Create_Environment
     (Creds           : Config.Credentials;
      Repo_Name       : String;
      Name            : String;
      Environment_Type : String := "Test") return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) & "/environments/";

      Data : constant String :=
        "{""type"":""deployment_environment""," &
        """name"":""" & Name & """," &
        """environment_type"":{""name"":""" & Environment_Type & """}}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Environment;

   function Delete_Environment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Env_UUID  : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/environments/" & Env_UUID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Environment;

   function List_Environment_Variables
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Env_UUID  : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/deployments_config/environments/" &
                               Env_UUID & "/variables";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Environment_Variables;

   ---------------------------------------------------------------------------
   --  Caches
   ---------------------------------------------------------------------------

   function List_Caches
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines-config/caches/";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Caches;

   function Delete_Cache
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Cache_UUID : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines-config/caches/" & Cache_UUID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Cache;

   function Delete_All_Caches
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines-config/caches/";
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_All_Caches;

   ---------------------------------------------------------------------------
   --  Schedules
   ---------------------------------------------------------------------------

   function List_Schedules
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/schedules/";
      Args : constant String :=
        "-s -X GET " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end List_Schedules;

   function Create_Schedule
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Cron_Pattern  : String;
      Target_Branch : String;
      Enabled       : Boolean := True) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/schedules/";

      Enabled_Str : constant String :=
        (if Enabled then "true" else "false");

      Data : constant String :=
        "{""type"":""pipeline_schedule""," &
        """enabled"":" & Enabled_Str & "," &
        """cron_pattern"":""" & Cron_Pattern & """," &
        """target"":{""ref_type"":""branch""," &
        """ref_name"":""" & Target_Branch & """}}";

      Args : constant String :=
        "-s -X POST " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Data & "' " & URL;
   begin
      return Run_Curl (Args);
   end Create_Schedule;

   function Update_Schedule
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Schedule_UUID : String;
      Cron_Pattern  : String := "";
      Enabled       : String := "") return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/schedules/" & Schedule_UUID;

      function Build_JSON return String is
         Result    : Unbounded_String := To_Unbounded_String ("{");
         Has_Field : Boolean := False;
      begin
         if Cron_Pattern'Length > 0 then
            Append (Result, """cron_pattern"":""" & Cron_Pattern & """");
            Has_Field := True;
         end if;

         if Enabled'Length > 0 then
            if Has_Field then
               Append (Result, ",");
            end if;
            Append (Result, """enabled"":" & Enabled);
         end if;

         Append (Result, "}");
         return To_String (Result);
      end Build_JSON;

      Args : constant String :=
        "-s -X PUT " & Auth_String (Creds) & " " &
        "-H ""Content-Type: application/json"" " &
        "-d '" & Build_JSON & "' " & URL;
   begin
      return Run_Curl (Args);
   end Update_Schedule;

   function Delete_Schedule
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Schedule_UUID : String) return Pipeline_Result
   is
      URL : constant String := Repo_URL (Creds, Repo_Name) &
                               "/pipelines_config/schedules/" & Schedule_UUID;
      Args : constant String :=
        "-s -X DELETE " & Auth_String (Creds) & " " & URL;
   begin
      return Run_Curl (Args);
   end Delete_Schedule;

   ---------------------------------------------------------------------------
   --  Utility Functions
   ---------------------------------------------------------------------------

   function State_To_String (S : Pipeline_State) return String is
   begin
      case S is
         when Pending     => return "PENDING";
         when In_Progress => return "IN_PROGRESS";
         when Completed   => return "COMPLETED";
         when Successful  => return "SUCCESSFUL";
         when Failed      => return "FAILED";
         when Error       => return "ERROR";
         when Stopped     => return "STOPPED";
         when Paused      => return "PAUSED";
      end case;
   end State_To_String;

   function String_To_State (S : String) return Pipeline_State is
      Upper : constant String := Ada.Characters.Handling.To_Upper (S);
   begin
      if Upper = "PENDING" then
         return Pending;
      elsif Upper = "IN_PROGRESS" then
         return In_Progress;
      elsif Upper = "COMPLETED" then
         return Completed;
      elsif Upper = "SUCCESSFUL" then
         return Successful;
      elsif Upper = "FAILED" then
         return Failed;
      elsif Upper = "ERROR" then
         return Error;
      elsif Upper = "STOPPED" then
         return Stopped;
      elsif Upper = "PAUSED" then
         return Paused;
      else
         return Pending;
      end if;
   end String_To_State;

   function Trigger_To_String (T : Trigger_Type) return String is
   begin
      case T is
         when Push         => return "push";
         when Pull_Request => return "pull_request";
         when Manual       => return "manual";
         when Schedule     => return "schedule";
         when Tag          => return "tag";
      end case;
   end Trigger_To_String;

   function Format_Duration (Seconds : Natural) return String is
      Hours   : constant Natural := Seconds / 3600;
      Minutes : constant Natural := (Seconds mod 3600) / 60;
      Secs    : constant Natural := Seconds mod 60;
   begin
      if Hours > 0 then
         return Ada.Strings.Fixed.Trim (Natural'Image (Hours), Ada.Strings.Left) &
                "h " &
                Ada.Strings.Fixed.Trim (Natural'Image (Minutes), Ada.Strings.Left) &
                "m " &
                Ada.Strings.Fixed.Trim (Natural'Image (Secs), Ada.Strings.Left) &
                "s";
      elsif Minutes > 0 then
         return Ada.Strings.Fixed.Trim (Natural'Image (Minutes), Ada.Strings.Left) &
                "m " &
                Ada.Strings.Fixed.Trim (Natural'Image (Secs), Ada.Strings.Left) &
                "s";
      else
         return Ada.Strings.Fixed.Trim (Natural'Image (Secs), Ada.Strings.Left) &
                "s";
      end if;
   end Format_Duration;

end Pipelines;
