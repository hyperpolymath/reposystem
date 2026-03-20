-- SPDX-License-Identifier: PMPL-1.0
-- Git_LFS - Git Large File Storage support for bitfuckit
-- Handles LFS operations when mirroring/cloning

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Git_LFS is

   type LFS_Status is (
      Available,        -- git-lfs installed and working
      Not_Installed,    -- git-lfs not found
      Not_Configured,   -- Installed but repo not using LFS
      Error             -- Something went wrong
   );

   type LFS_Info is record
      Status       : LFS_Status := Not_Installed;
      Version      : Unbounded_String := Null_Unbounded_String;
      Endpoint     : Unbounded_String := Null_Unbounded_String;
      Tracked_Patterns : Unbounded_String := Null_Unbounded_String;
      Total_Files  : Natural := 0;
      Total_Size   : Natural := 0;
   end record;

   -- Check if git-lfs is available
   function Is_LFS_Installed return Boolean;
   function Get_LFS_Version return String;

   -- Repository LFS status
   function Get_LFS_Info (Repo_Path : String := ".") return LFS_Info;
   function Is_LFS_Enabled (Repo_Path : String := ".") return Boolean;

   -- LFS operations
   procedure Install_LFS;  -- git lfs install
   procedure Track (Pattern : String; Repo_Path : String := ".");
   procedure Untrack (Pattern : String; Repo_Path : String := ".");
   function List_Tracked return String;

   -- Fetch/Pull LFS objects
   procedure Fetch_LFS (Repo_Path : String := "."; Show_Progress : Boolean := True);
   procedure Pull_LFS (Repo_Path : String := "."; Show_Progress : Boolean := True);
   procedure Push_LFS (Repo_Path : String := "."; Show_Progress : Boolean := True);

   -- Migrate operations (convert to/from LFS)
   procedure Migrate_Import
     (Patterns : String;
      Repo_Path : String := ".";
      Include_History : Boolean := False);

   procedure Migrate_Export
     (Patterns : String;
      Repo_Path : String := ".");

   -- Bitbucket-specific LFS setup
   procedure Configure_For_Bitbucket
     (Workspace : String;
      Repo_Name : String;
      Repo_Path : String := ".");

   -- Prune/cleanup
   procedure Prune (Repo_Path : String := ".");
   function Get_LFS_Size (Repo_Path : String := ".") return Natural;

   -- Lock management (LFS file locking)
   procedure Lock_File (File_Path : String);
   procedure Unlock_File (File_Path : String; Force : Boolean := False);
   function List_Locks return String;

end Git_LFS;
