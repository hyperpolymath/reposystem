-- SPDX-License-Identifier: PMPL-1.0
-- Webhook management for bitfuckit
-- Create, list, update, and delete webhooks

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package Webhooks is

   --  Result type for webhook operations
   type Webhook_Result is record
      Success      : Boolean;
      Message      : Unbounded_String;
      Data         : Unbounded_String;
      Webhook_UUID : Unbounded_String;
   end record;

   --  Webhook events (Bitbucket events that can trigger webhooks)
   --  Multiple events can be combined

   type Webhook_Event is
     (--  Repository events
      Repo_Push,
      Repo_Fork,
      Repo_Updated,
      Repo_Commit_Comment_Created,
      Repo_Commit_Status_Created,
      Repo_Commit_Status_Updated,
      --  Pull request events
      PR_Created,
      PR_Updated,
      PR_Approved,
      PR_Unapproved,
      PR_Merged,
      PR_Declined,
      PR_Comment_Created,
      PR_Comment_Updated,
      PR_Comment_Deleted,
      --  Issue events
      Issue_Created,
      Issue_Updated,
      Issue_Comment_Created);

   type Event_Set is array (Webhook_Event) of Boolean;

   --  Commonly used event sets
   All_Events       : constant Event_Set := (others => True);
   Push_Events      : constant Event_Set :=
     (Repo_Push => True, others => False);
   PR_Events        : constant Event_Set :=
     (PR_Created | PR_Updated | PR_Approved | PR_Unapproved |
      PR_Merged | PR_Declined => True, others => False);
   Issue_Events     : constant Event_Set :=
     (Issue_Created | Issue_Updated | Issue_Comment_Created => True,
      others => False);

   ----------------------------------------------------------------------------
   --  Webhook CRUD
   ----------------------------------------------------------------------------

   function Create_Webhook
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      URL         : String;
      Description : String := "";
      Events      : Event_Set := Push_Events;
      Active      : Boolean := True;
      Secret      : String := "") return Webhook_Result;
   --  Create a new webhook
   --  Secret: Optional secret for HMAC signature verification

   function Get_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result;
   --  Get details of a specific webhook

   function List_Webhooks
     (Creds     : Config.Credentials;
      Repo_Name : String) return Webhook_Result;
   --  List all webhooks for a repository

   function Update_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String;
      URL          : String := "";
      Description  : String := "";
      Events       : String := "";
      Active       : String := "";
      Secret       : String := "") return Webhook_Result;
   --  Update webhook configuration
   --  Empty fields are not updated
   --  Events should be comma-separated event names

   function Delete_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result;
   --  Delete a webhook

   ----------------------------------------------------------------------------
   --  Webhook Control
   ----------------------------------------------------------------------------

   function Enable_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result;
   --  Enable a disabled webhook

   function Disable_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result;
   --  Disable a webhook without deleting it

   function Test_Webhook
     (Creds        : Config.Credentials;
      Repo_Name    : String;
      Webhook_UUID : String) return Webhook_Result;
   --  Send a test payload to the webhook URL

   ----------------------------------------------------------------------------
   --  Workspace Webhooks
   ----------------------------------------------------------------------------

   function Create_Workspace_Webhook
     (Creds       : Config.Credentials;
      URL         : String;
      Description : String := "";
      Events      : Event_Set := Push_Events;
      Active      : Boolean := True) return Webhook_Result;
   --  Create a webhook that applies to all repos in workspace

   function List_Workspace_Webhooks
     (Creds : Config.Credentials) return Webhook_Result;
   --  List workspace-level webhooks

   function Delete_Workspace_Webhook
     (Creds        : Config.Credentials;
      Webhook_UUID : String) return Webhook_Result;
   --  Delete a workspace webhook

   ----------------------------------------------------------------------------
   --  Utility Functions
   ----------------------------------------------------------------------------

   function Event_To_String (E : Webhook_Event) return String;
   function String_To_Event (S : String) return Webhook_Event;
   function Events_To_JSON (Events : Event_Set) return String;
   function Parse_Events_String (S : String) return Event_Set;

end Webhooks;
