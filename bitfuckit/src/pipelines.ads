-- SPDX-License-Identifier: PMPL-1.0
-- Bitbucket Pipelines integration for bitfuckit
-- Pipeline status, triggers, logs, and configuration

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package Pipelines is

   --  Result type for pipeline operations
   type Pipeline_Result is record
      Success      : Boolean;
      Message      : Unbounded_String;
      Data         : Unbounded_String;
      Pipeline_UUID : Unbounded_String;
      Build_Number : Natural := 0;
   end record;

   --  Pipeline state enumeration
   type Pipeline_State is (Pending, In_Progress, Completed,
                           Successful, Failed, Error, Stopped, Paused);

   --  Pipeline trigger type
   type Trigger_Type is (Push, Pull_Request, Manual, Schedule, Tag);

   --  Step state enumeration
   type Step_State is (Pending, In_Progress, Completed,
                       Successful, Failed, Not_Run, Skipped);

   ----------------------------------------------------------------------------
   --  Pipeline Configuration
   ----------------------------------------------------------------------------

   function Get_Config
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  Get pipeline configuration (bitbucket-pipelines.yml content)

   function Update_Config
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Content   : String) return Pipeline_Result;
   --  Update pipeline configuration

   function Is_Enabled
     (Creds     : Config.Credentials;
      Repo_Name : String) return Boolean;
   --  Check if pipelines are enabled for repository

   function Enable_Pipelines
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  Enable pipelines for repository

   function Disable_Pipelines
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  Disable pipelines for repository

   ----------------------------------------------------------------------------
   --  Pipeline Listing
   ----------------------------------------------------------------------------

   function List_Pipelines
     (Creds     : Config.Credentials;
      Repo_Name : String;
      State     : String := "";
      Target_Branch : String := "";
      Page_Len  : Positive := 25) return Pipeline_Result;
   --  List pipeline runs with optional filters

   function Get_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result;
   --  Get details of a specific pipeline run

   function Get_Latest_Pipeline
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Branch    : String := "") return Pipeline_Result;
   --  Get the most recent pipeline run

   ----------------------------------------------------------------------------
   --  Pipeline Triggers
   ----------------------------------------------------------------------------

   function Trigger_Pipeline
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Target    : String;
      Variables : String := "") return Pipeline_Result;
   --  Trigger a pipeline run on branch/tag
   --  Variables: JSON object of pipeline variables

   function Trigger_Custom_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Target        : String;
      Pipeline_Name : String;
      Variables     : String := "") return Pipeline_Result;
   --  Trigger a custom pipeline by name

   function Trigger_PR_Pipeline
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return Pipeline_Result;
   --  Trigger pipeline for a pull request

   ----------------------------------------------------------------------------
   --  Pipeline Control
   ----------------------------------------------------------------------------

   function Stop_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result;
   --  Stop a running pipeline

   function Rerun_Pipeline
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result;
   --  Rerun a pipeline

   ----------------------------------------------------------------------------
   --  Pipeline Steps
   ----------------------------------------------------------------------------

   function List_Steps
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String) return Pipeline_Result;
   --  List steps in a pipeline

   function Get_Step
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String;
      Step_UUID     : String) return Pipeline_Result;
   --  Get details of a specific step

   function Get_Step_Log
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Pipeline_UUID : String;
      Step_UUID     : String) return Pipeline_Result;
   --  Get log output from a step

   ----------------------------------------------------------------------------
   --  Pipeline Variables
   ----------------------------------------------------------------------------

   function List_Variables
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  List repository pipeline variables

   function Create_Variable
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Key       : String;
      Value     : String;
      Secured   : Boolean := False) return Pipeline_Result;
   --  Create a pipeline variable

   function Update_Variable
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Var_UUID  : String;
      Value     : String;
      Secured   : Boolean := False) return Pipeline_Result;
   --  Update a pipeline variable

   function Delete_Variable
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Var_UUID  : String) return Pipeline_Result;
   --  Delete a pipeline variable

   ----------------------------------------------------------------------------
   --  Deployment Environments
   ----------------------------------------------------------------------------

   function List_Environments
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  List deployment environments

   function Get_Environment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Env_UUID  : String) return Pipeline_Result;
   --  Get environment details

   function Create_Environment
     (Creds           : Config.Credentials;
      Repo_Name       : String;
      Name            : String;
      Environment_Type : String := "Test") return Pipeline_Result;
   --  Create deployment environment
   --  Environment_Type: Test, Staging, Production

   function Delete_Environment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Env_UUID  : String) return Pipeline_Result;
   --  Delete deployment environment

   function List_Environment_Variables
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Env_UUID  : String) return Pipeline_Result;
   --  List variables for an environment

   ----------------------------------------------------------------------------
   --  Caches
   ----------------------------------------------------------------------------

   function List_Caches
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  List pipeline caches

   function Delete_Cache
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Cache_UUID : String) return Pipeline_Result;
   --  Delete a specific cache

   function Delete_All_Caches
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  Delete all caches for repository

   ----------------------------------------------------------------------------
   --  Schedules
   ----------------------------------------------------------------------------

   function List_Schedules
     (Creds     : Config.Credentials;
      Repo_Name : String) return Pipeline_Result;
   --  List pipeline schedules

   function Create_Schedule
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Cron_Pattern  : String;
      Target_Branch : String;
      Enabled       : Boolean := True) return Pipeline_Result;
   --  Create a scheduled pipeline

   function Update_Schedule
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Schedule_UUID : String;
      Cron_Pattern  : String := "";
      Enabled       : String := "") return Pipeline_Result;
   --  Update a schedule

   function Delete_Schedule
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Schedule_UUID : String) return Pipeline_Result;
   --  Delete a schedule

   ----------------------------------------------------------------------------
   --  Utility Functions
   ----------------------------------------------------------------------------

   function State_To_String (S : Pipeline_State) return String;
   function String_To_State (S : String) return Pipeline_State;
   function Trigger_To_String (T : Trigger_Type) return String;

   function Format_Duration (Seconds : Natural) return String;
   --  Format duration as human-readable string (e.g., "2m 34s")

end Pipelines;
