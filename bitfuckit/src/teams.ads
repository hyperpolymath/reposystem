-- SPDX-License-Identifier: PMPL-1.0
-- Team and permission management for bitfuckit
-- Workspace members, groups, and repository permissions

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package Teams is

   --  Result type for team operations
   type Team_Result is record
      Success : Boolean;
      Message : Unbounded_String;
      Data    : Unbounded_String;
   end record;

   --  Permission levels
   type Permission_Level is (Read, Write, Admin);

   --  Member role in workspace
   type Workspace_Role is (Member, Collaborator, Owner);

   ----------------------------------------------------------------------------
   --  Workspace Members
   ----------------------------------------------------------------------------

   function List_Members
     (Creds : Config.Credentials) return Team_Result;
   --  List all members in workspace

   function Get_Member
     (Creds    : Config.Credentials;
      Username : String) return Team_Result;
   --  Get details of a specific member

   function Invite_Member
     (Creds    : Config.Credentials;
      Email    : String;
      Groups   : String := "") return Team_Result;
   --  Invite a user to workspace by email
   --  Groups: comma-separated list of group slugs

   function Remove_Member
     (Creds    : Config.Credentials;
      Username : String) return Team_Result;
   --  Remove a member from workspace

   ----------------------------------------------------------------------------
   --  User Groups
   ----------------------------------------------------------------------------

   function List_Groups
     (Creds : Config.Credentials) return Team_Result;
   --  List all groups in workspace

   function Create_Group
     (Creds       : Config.Credentials;
      Name        : String;
      Permission  : Permission_Level := Read;
      Auto_Add    : Boolean := False) return Team_Result;
   --  Create a new group
   --  Auto_Add: automatically add new members to this group

   function Get_Group
     (Creds      : Config.Credentials;
      Group_Slug : String) return Team_Result;
   --  Get details of a specific group

   function Update_Group
     (Creds      : Config.Credentials;
      Group_Slug : String;
      Name       : String := "";
      Permission : String := "";
      Auto_Add   : String := "") return Team_Result;
   --  Update group settings

   function Delete_Group
     (Creds      : Config.Credentials;
      Group_Slug : String) return Team_Result;
   --  Delete a group

   function List_Group_Members
     (Creds      : Config.Credentials;
      Group_Slug : String) return Team_Result;
   --  List members of a group

   function Add_Group_Member
     (Creds      : Config.Credentials;
      Group_Slug : String;
      Username   : String) return Team_Result;
   --  Add a user to a group

   function Remove_Group_Member
     (Creds      : Config.Credentials;
      Group_Slug : String;
      Username   : String) return Team_Result;
   --  Remove a user from a group

   ----------------------------------------------------------------------------
   --  Repository Permissions
   ----------------------------------------------------------------------------

   function List_Repo_Permissions
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result;
   --  List all permissions for a repository

   function Get_User_Permission
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result;
   --  Get specific user's permission on a repo

   function Grant_User_Permission
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Username   : String;
      Permission : Permission_Level) return Team_Result;
   --  Grant a user permission to a repository

   function Revoke_User_Permission
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result;
   --  Revoke a user's permission from a repository

   function Grant_Group_Permission
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Group_Slug : String;
      Permission : Permission_Level) return Team_Result;
   --  Grant a group permission to a repository

   function Revoke_Group_Permission
     (Creds      : Config.Credentials;
      Repo_Name  : String;
      Group_Slug : String) return Team_Result;
   --  Revoke a group's permission from a repository

   ----------------------------------------------------------------------------
   --  Branch Restrictions
   ----------------------------------------------------------------------------

   function List_Branch_Restrictions
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result;
   --  List all branch restrictions for a repository

   function Create_Branch_Restriction
     (Creds            : Config.Credentials;
      Repo_Name        : String;
      Kind             : String;
      Branch_Match_Kind : String := "glob";
      Pattern          : String := "main";
      Users            : String := "";
      Groups           : String := "") return Team_Result;
   --  Create a branch restriction
   --  Kind: push, force, delete, restrict_merges, require_approvals, etc.
   --  Branch_Match_Kind: glob, branching_model
   --  Pattern: branch pattern (e.g., "main", "release/*")
   --  Users/Groups: comma-separated lists of allowed users/groups

   function Delete_Branch_Restriction
     (Creds          : Config.Credentials;
      Repo_Name      : String;
      Restriction_ID : String) return Team_Result;
   --  Delete a branch restriction

   ----------------------------------------------------------------------------
   --  Default Reviewers
   ----------------------------------------------------------------------------

   function List_Default_Reviewers
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result;
   --  List default reviewers for a repository

   function Add_Default_Reviewer
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result;
   --  Add a default reviewer

   function Remove_Default_Reviewer
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Username  : String) return Team_Result;
   --  Remove a default reviewer

   ----------------------------------------------------------------------------
   --  SSH Keys (Deploy Keys)
   ----------------------------------------------------------------------------

   function List_Deploy_Keys
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result;
   --  List deploy keys for a repository

   function Add_Deploy_Key
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Key       : String;
      Label     : String) return Team_Result;
   --  Add a deploy key to repository

   function Delete_Deploy_Key
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Key_ID    : String) return Team_Result;
   --  Delete a deploy key

   ----------------------------------------------------------------------------
   --  Access Tokens
   ----------------------------------------------------------------------------

   function List_Access_Tokens
     (Creds     : Config.Credentials;
      Repo_Name : String) return Team_Result;
   --  List repository access tokens

   function Create_Access_Token
     (Creds       : Config.Credentials;
      Repo_Name   : String;
      Name        : String;
      Scopes      : String;
      Expires_On  : String := "") return Team_Result;
   --  Create a repository access token
   --  Scopes: comma-separated (repository, repository:write, etc.)
   --  Expires_On: ISO 8601 date (optional)

   function Revoke_Access_Token
     (Creds     : Config.Credentials;
      Repo_Name : String;
      Token_ID  : String) return Team_Result;
   --  Revoke an access token

   ----------------------------------------------------------------------------
   --  Utility Functions
   ----------------------------------------------------------------------------

   function Permission_To_String (P : Permission_Level) return String;
   function String_To_Permission (S : String) return Permission_Level;
   function Role_To_String (R : Workspace_Role) return String;

end Teams;
