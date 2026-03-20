-- SPDX-License-Identifier: PMPL-1.0
-- Issue tracking operations for bitfuckit
-- Full CRUD operations for Bitbucket issues

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package Issues is

   --  Result type for issue operations
   type Issue_Result is record
      Success   : Boolean;
      Message   : Unbounded_String;
      Data      : Unbounded_String;
      Issue_ID  : Natural := 0;
      Issue_URL : Unbounded_String;
   end record;

   --  Issue state enumeration
   type Issue_State is (Open_Issue, New_Issue, On_Hold, Resolved,
                        Duplicate, Invalid, Wontfix, Closed);

   --  Issue priority enumeration
   type Issue_Priority is (Trivial, Minor, Major, Critical, Blocker);

   --  Issue kind enumeration
   type Issue_Kind is (Bug, Enhancement, Proposal, Task_Item);

   ----------------------------------------------------------------------------
   --  Issue CRUD
   ----------------------------------------------------------------------------

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
      Version     : String := "") return Issue_Result;
   --  Create a new issue

   function Get_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Get details of a specific issue

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
      Version     : String := "") return Issue_Result;
   --  Update an existing issue (empty fields are not updated)

   function Delete_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Delete an issue

   ----------------------------------------------------------------------------
   --  Issue Listing
   ----------------------------------------------------------------------------

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
      Page_Len   : Positive := 25) return Issue_Result;
   --  List issues with filters
   --  Sort: created_on, -created_on, updated_on, -updated_on, priority, etc.

   ----------------------------------------------------------------------------
   --  Issue Comments
   ----------------------------------------------------------------------------

   function Add_Comment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive;
      Content   : String) return Issue_Result;
   --  Add a comment to an issue

   function List_Comments
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  List comments on an issue

   function Update_Comment
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Issue_ID   : Positive;
      Comment_ID : Positive;
      Content    : String) return Issue_Result;
   --  Update a comment

   function Delete_Comment
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Issue_ID   : Positive;
      Comment_ID : Positive) return Issue_Result;
   --  Delete a comment

   ----------------------------------------------------------------------------
   --  Issue Attachments
   ----------------------------------------------------------------------------

   function Add_Attachment
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive;
      File_Path : String) return Issue_Result;
   --  Attach a file to an issue

   function List_Attachments
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  List attachments on an issue

   function Delete_Attachment
     (Creds         : Config.Credentials;
      Repo_Name     : String;
      Issue_ID      : Positive;
      Attachment_ID : Positive) return Issue_Result;
   --  Delete an attachment

   ----------------------------------------------------------------------------
   --  Issue Watch/Vote
   ----------------------------------------------------------------------------

   function Watch_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Start watching an issue

   function Unwatch_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Stop watching an issue

   function Vote_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Vote for an issue

   function Unvote_Issue
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Remove vote from an issue

   ----------------------------------------------------------------------------
   --  Issue Changes/History
   ----------------------------------------------------------------------------

   function Get_Changes
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Issue_ID  : Positive) return Issue_Result;
   --  Get changelog/history of an issue

   ----------------------------------------------------------------------------
   --  Utility Functions
   ----------------------------------------------------------------------------

   function State_To_String (S : Issue_State) return String;
   function String_To_State (S : String) return Issue_State;
   function Priority_To_String (P : Issue_Priority) return String;
   function String_To_Priority (S : String) return Issue_Priority;
   function Kind_To_String (K : Issue_Kind) return String;
   function String_To_Kind (S : String) return Issue_Kind;

end Issues;
