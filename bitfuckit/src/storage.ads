-- SPDX-License-Identifier: PMPL-1.0
-- Storage - Persistent storage abstraction with CubsDB and OpenTimestamp
-- Provides robust, timestamped, verifiable storage for bitfuckit

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Calendar; use Ada.Calendar;

package Storage is

   -- Storage backends
   type Backend_Type is (
      File_Backend,     -- Simple file storage (default)
      CubsDB_Backend,   -- CubsDB for robust storage
      SQLite_Backend    -- SQLite fallback
   );

   -- Timestamp verification status
   type Timestamp_Status is (
      Verified,         -- OpenTimestamp verified on Bitcoin blockchain
      Pending,          -- Submitted to calendar servers, awaiting confirmation
      Unverified,       -- Not timestamped
      Error             -- Timestamp verification failed
   );

   type Timestamped_Record is record
      Key           : Unbounded_String := Null_Unbounded_String;
      Value         : Unbounded_String := Null_Unbounded_String;
      Created_At    : Time := Clock;
      Modified_At   : Time := Clock;
      OTS_Status    : Timestamp_Status := Unverified;
      OTS_Proof     : Unbounded_String := Null_Unbounded_String;  -- Base64 .ots file
      Hash          : Unbounded_String := Null_Unbounded_String;  -- SHA-256 of value
   end record;

   -- Initialization
   procedure Initialize (Backend : Backend_Type := File_Backend);
   procedure Close;
   function Is_Initialized return Boolean;
   function Get_Current_Backend return Backend_Type;

   -- Basic CRUD operations
   procedure Put
     (Key   : String;
      Value : String;
      Timestamp : Boolean := False);

   function Get (Key : String) return String;
   function Exists (Key : String) return Boolean;
   procedure Delete (Key : String);

   -- Timestamped operations (uses OpenTimestamp)
   procedure Put_Timestamped
     (Key   : String;
      Value : String);

   function Get_With_Timestamp (Key : String) return Timestamped_Record;
   function Verify_Timestamp (Key : String) return Timestamp_Status;
   procedure Upgrade_Timestamps;  -- Check pending timestamps for confirmation

   -- Batch operations
   procedure Put_Batch (Pairs : String);  -- JSON format: [{"k":"v"}, ...]
   function Get_All_Keys return String;

   -- CubsDB-specific
   procedure Configure_CubsDB
     (Path     : String := "~/.local/share/bitfuckit/cubsdb";
      Options  : String := "");

   -- Maintenance
   procedure Compact;
   procedure Backup (Destination : String);
   procedure Restore (Source : String);
   function Get_Stats return String;

private
   Current_Backend : Backend_Type := File_Backend;
   Initialized : Boolean := False;
   CubsDB_Path : Unbounded_String := Null_Unbounded_String;

end Storage;
