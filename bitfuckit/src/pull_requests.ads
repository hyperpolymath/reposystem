-- SPDX-License-Identifier: PMPL-1.0
-- Pull Request operations for bitfuckit
-- Provides full PR workflow: create, view, merge, decline, approve, comment

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package Pull_Requests is

   --  Result type for PR operations
   type PR_Result is record
      Success    : Boolean;
      Message    : Unbounded_String;
      Data       : Unbounded_String;
      PR_ID      : Natural := 0;
      PR_URL     : Unbounded_String;
   end record;

   --  PR state enumeration
   type PR_State is (Open, Merged, Declined, Superseded);

   --  Merge strategy enumeration
   type Merge_Strategy is (Merge_Commit, Squash, Fast_Forward);

   --  Review status enumeration
   type Review_Status is (Approved, Changes_Requested, Unapproved);

   ----------------------------------------------------------------------------
   --  PR Creation
   ----------------------------------------------------------------------------

   function Create_PR
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Title         : String;
      Source_Branch : String;
      Dest_Branch   : String := "main";
      Description   : String := "";
      Reviewers     : String := "";
      Close_Source  : Boolean := False) return PR_Result;
   --  Create a new pull request
   --  Reviewers is a comma-separated list of usernames

   ----------------------------------------------------------------------------
   --  PR Viewing
   ----------------------------------------------------------------------------

   function Get_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Get details of a specific PR

   function List_PRs
     (Creds     : Config.Credentials;
      Repo_Name : String;
      State     : PR_State := Open;
      Author    : String := "";
      Page_Len  : Positive := 25) return PR_Result;
   --  List pull requests with optional filters

   function Get_PR_Diff
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Get the diff for a PR

   function Get_PR_Commits
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Get commits in a PR

   ----------------------------------------------------------------------------
   --  PR Actions
   ----------------------------------------------------------------------------

   function Merge_PR
     (Creds          : Config.Credentials;
      Repo_Name      : String;
      PR_ID          : Positive;
      Strategy       : Merge_Strategy := Merge_Commit;
      Message        : String := "";
      Close_Source   : Boolean := True) return PR_Result;
   --  Merge a pull request

   function Decline_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      Reason    : String := "") return PR_Result;
   --  Decline a pull request

   function Update_PR
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      PR_ID       : Positive;
      Title       : String := "";
      Description : String := "";
      Dest_Branch : String := "") return PR_Result;
   --  Update PR title, description, or destination branch

   ----------------------------------------------------------------------------
   --  PR Reviews
   ----------------------------------------------------------------------------

   function Approve_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Approve a pull request

   function Unapprove_PR
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Remove approval from a pull request

   function Request_Changes
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      Comment   : String) return PR_Result;
   --  Request changes on a pull request

   function Get_Approvals
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Get list of approvals for a PR

   ----------------------------------------------------------------------------
   --  PR Comments
   ----------------------------------------------------------------------------

   function Add_Comment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      Content   : String) return PR_Result;
   --  Add a general comment to a PR

   function Add_Inline_Comment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive;
      File_Path : String;
      Line      : Positive;
      Content   : String) return PR_Result;
   --  Add an inline comment to a specific line in a file

   function List_Comments
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  List all comments on a PR

   function Delete_Comment
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      PR_ID      : Positive;
      Comment_ID : Positive) return PR_Result;
   --  Delete a comment (must be author)

   ----------------------------------------------------------------------------
   --  PR Status
   ----------------------------------------------------------------------------

   function Get_Build_Status
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return PR_Result;
   --  Get build/pipeline status for a PR

   function Can_Merge
     (Creds     : Config.Credentials;
      Repo_Name : String;
      PR_ID     : Positive) return Boolean;
   --  Check if PR can be merged (no conflicts, approvals met)

   ----------------------------------------------------------------------------
   --  Utility Functions
   ----------------------------------------------------------------------------

   function State_To_String (S : PR_State) return String;
   function String_To_State (S : String) return PR_State;
   function Strategy_To_String (S : Merge_Strategy) return String;

end Pull_Requests;
