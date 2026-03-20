-- SPDX-License-Identifier: PMPL-1.0
-- Syncthing_Sync - Integration with Syncthing for distributed config sync
-- Enables secure, decentralized synchronization of bitfuckit state

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Syncthing_Sync is

   type Sync_Status is (
      Synced,           -- All up to date
      Syncing,          -- Currently synchronizing
      Out_Of_Sync,      -- Needs sync
      Conflict,         -- Conflict detected
      Disconnected,     -- Syncthing not reachable
      Not_Configured    -- Syncthing folder not set up
   );

   type Sync_Info is record
      Status         : Sync_Status := Not_Configured;
      Last_Sync_Time : Unbounded_String := Null_Unbounded_String;
      Pending_Items  : Natural := 0;
      Connected_Peers : Natural := 0;
      Message        : Unbounded_String := Null_Unbounded_String;
   end record;

   -- Configuration
   procedure Configure_Syncthing
     (API_Key   : String;
      API_URL   : String := "http://127.0.0.1:8384");

   function Is_Syncthing_Configured return Boolean;
   function Is_Syncthing_Running return Boolean;

   -- Folder management for bitfuckit data
   procedure Setup_Bitfuckit_Folder
     (Folder_Path : String := "~/.local/share/bitfuckit");

   function Get_Sync_Status return Sync_Info;

   -- Force operations
   procedure Force_Sync;
   procedure Rescan_Folder;

   -- Conflict resolution
   procedure Accept_Local_Version (File_Path : String);
   procedure Accept_Remote_Version (File_Path : String);
   function Get_Conflict_Files return String;

   -- Device management
   procedure Add_Device (Device_ID : String; Name : String := "");
   procedure Remove_Device (Device_ID : String);
   function List_Connected_Devices return String;

   -- Configuration sync helpers
   procedure Sync_Credentials;
   procedure Sync_Settings;

private
   ST_API_Key : Unbounded_String := Null_Unbounded_String;
   ST_API_URL : Unbounded_String := To_Unbounded_String ("http://127.0.0.1:8384");
   Configured : Boolean := False;

end Syncthing_Sync;
