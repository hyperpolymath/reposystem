-- SPDX-License-Identifier: PMPL-1.0
-- Storage implementation with CubsDB and OpenTimestamp support

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;
with GNAT.Expect; use GNAT.Expect;
with GNAT.SHA256;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Environment_Variables;

package body Storage is

   Data_Dir : Unbounded_String := Null_Unbounded_String;

   function Get_Data_Dir return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME", "/tmp");
   begin
      if Length (Data_Dir) > 0 then
         return To_String (Data_Dir);
      else
         return Home & "/.local/share/bitfuckit";
      end if;
   end Get_Data_Dir;

   function Compute_Hash (Value : String) return String is
      Ctx : GNAT.SHA256.Context;
   begin
      GNAT.SHA256.Update (Ctx, Value);
      return GNAT.SHA256.Digest (Ctx);
   end Compute_Hash;

   procedure Initialize (Backend : Backend_Type := File_Backend) is
      Dir : constant String := Get_Data_Dir;
   begin
      Current_Backend := Backend;

      -- Create data directory if needed
      if not Ada.Directories.Exists (Dir) then
         Ada.Directories.Create_Path (Dir);
      end if;

      case Backend is
         when File_Backend =>
            -- File backend: just use the directory
            Initialized := True;

         when CubsDB_Backend =>
            -- CubsDB: check if cubs binary is available
            declare
               Cubs_Path : GNAT.OS_Lib.String_Access;
            begin
               Cubs_Path := GNAT.OS_Lib.Locate_Exec_On_Path ("cubs");
               if Cubs_Path = null then
                  -- Fall back to file backend
                  Current_Backend := File_Backend;
               else
                  CubsDB_Path := To_Unbounded_String (Dir & "/cubsdb");
               end if;
               Initialized := True;
            end;

         when SQLite_Backend =>
            -- SQLite: would need additional bindings
            Current_Backend := File_Backend;
            Initialized := True;
      end case;
   end Initialize;

   procedure Close is
   begin
      Initialized := False;
   end Close;

   function Is_Initialized return Boolean is
   begin
      return Initialized;
   end Is_Initialized;

   function Get_Current_Backend return Backend_Type is
   begin
      return Current_Backend;
   end Get_Current_Backend;

   function Key_To_Path (Key : String) return String is
   begin
      return Get_Data_Dir & "/" & Key & ".dat";
   end Key_To_Path;

   procedure Put
     (Key   : String;
      Value : String;
      Timestamp : Boolean := False)
   is
      Path : constant String := Key_To_Path (Key);
      File : Ada.Text_IO.File_Type;
   begin
      if not Initialized then
         Initialize;
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      Ada.Text_IO.Put (File, Value);
      Ada.Text_IO.Close (File);

      if Timestamp then
         Put_Timestamped (Key, Value);
      end if;
   end Put;

   function Get (Key : String) return String is
      Path : constant String := Key_To_Path (Key);
      File : Ada.Text_IO.File_Type;
      Content : Unbounded_String := Null_Unbounded_String;
      Line : String (1 .. 4096);
      Last : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Line, Last);
         Append (Content, Line (1 .. Last));
         if not Ada.Text_IO.End_Of_File (File) then
            Append (Content, ASCII.LF);
         end if;
      end loop;
      Ada.Text_IO.Close (File);

      return To_String (Content);
   end Get;

   function Exists (Key : String) return Boolean is
   begin
      return Ada.Directories.Exists (Key_To_Path (Key));
   end Exists;

   procedure Delete (Key : String) is
      Path : constant String := Key_To_Path (Key);
      OTS_Path : constant String := Key_To_Path (Key & ".ots");
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_File (Path);
      end if;
      if Ada.Directories.Exists (OTS_Path) then
         Ada.Directories.Delete_File (OTS_Path);
      end if;
   end Delete;

   procedure Put_Timestamped
     (Key   : String;
      Value : String)
   is
      Path : constant String := Key_To_Path (Key);
      OTS_Path : constant String := Key_To_Path (Key & ".ots");
      Hash : constant String := Compute_Hash (Value);
      Ret : Integer;
   begin
      -- First store the value
      Put (Key, Value, Timestamp => False);

      -- Store the hash
      Put (Key & ".hash", Hash, Timestamp => False);

      -- Call ots (OpenTimestamp CLI) to create timestamp
      declare
         OTS_Path_Str : GNAT.OS_Lib.String_Access;
      begin
         OTS_Path_Str := GNAT.OS_Lib.Locate_Exec_On_Path ("ots");
         if OTS_Path_Str /= null then
            Ret := GNAT.OS_Lib.Spawn
              (Program_Name => "ots",
               Args => GNAT.OS_Lib.Argument_String_To_List
                 ("stamp " & Path).all);
         end if;
      end;
   end Put_Timestamped;

   function Get_With_Timestamp (Key : String) return Timestamped_Record is
      Rec : Timestamped_Record;
      Path : constant String := Key_To_Path (Key);
      OTS_Path : constant String := Path & ".ots";
   begin
      Rec.Key := To_Unbounded_String (Key);

      if not Exists (Key) then
         return Rec;
      end if;

      Rec.Value := To_Unbounded_String (Get (Key));
      Rec.Hash := To_Unbounded_String (Get (Key & ".hash"));

      if Ada.Directories.Exists (OTS_Path) then
         Rec.OTS_Status := Pending;  -- Would need to verify
      else
         Rec.OTS_Status := Unverified;
      end if;

      return Rec;
   end Get_With_Timestamp;

   function Verify_Timestamp (Key : String) return Timestamp_Status is
      Path : constant String := Key_To_Path (Key);
      OTS_Path : constant String := Path & ".ots";
      Ret : Integer;
      OTS_Cmd : GNAT.OS_Lib.String_Access;
   begin
      if not Ada.Directories.Exists (OTS_Path) then
         return Unverified;
      end if;

      OTS_Cmd := GNAT.OS_Lib.Locate_Exec_On_Path ("ots");
      if OTS_Cmd = null then
         return Error;
      end if;

      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "ots",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("verify " & OTS_Path).all);

      if Ret = 0 then
         return Verified;
      else
         return Pending;
      end if;
   end Verify_Timestamp;

   procedure Upgrade_Timestamps is
      Ret : Integer;
      OTS_Cmd : GNAT.OS_Lib.String_Access;
   begin
      OTS_Cmd := GNAT.OS_Lib.Locate_Exec_On_Path ("ots");
      if OTS_Cmd = null then
         return;
      end if;

      -- Upgrade all .ots files in data directory
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/bin/sh",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("-c 'ots upgrade " & Get_Data_Dir & "/*.ots 2>/dev/null'").all);
   end Upgrade_Timestamps;

   procedure Put_Batch (Pairs : String) is
   begin
      -- TODO: Parse JSON and store each key-value pair
      null;
   end Put_Batch;

   function Get_All_Keys return String is
      Result : Unbounded_String := Null_Unbounded_String;
      Search : Ada.Directories.Search_Type;
      Entry_Info : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Get_Data_Dir, "*.dat",
         (Ada.Directories.Ordinary_File => True, others => False));

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Entry_Info);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Entry_Info);
         begin
            if Name'Length > 4 then
               if Length (Result) > 0 then
                  Append (Result, ",");
               end if;
               Append (Result, Name (Name'First .. Name'Last - 4));
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      return To_String (Result);
   end Get_All_Keys;

   procedure Configure_CubsDB
     (Path     : String := "~/.local/share/bitfuckit/cubsdb";
      Options  : String := "")
   is
   begin
      CubsDB_Path := To_Unbounded_String (Path);
      Current_Backend := CubsDB_Backend;
   end Configure_CubsDB;

   procedure Compact is
   begin
      null;  -- No-op for file backend
   end Compact;

   procedure Backup (Destination : String) is
      Ret : Integer;
   begin
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/cp",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("-r " & Get_Data_Dir & " " & Destination).all);
   end Backup;

   procedure Restore (Source : String) is
      Ret : Integer;
   begin
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/cp",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("-r " & Source & "/* " & Get_Data_Dir & "/").all);
   end Restore;

   function Get_Stats return String is
      Count : Natural := 0;
      Search : Ada.Directories.Search_Type;
      Entry_Info : Ada.Directories.Directory_Entry_Type;
   begin
      if not Ada.Directories.Exists (Get_Data_Dir) then
         return "{""keys"":0,""backend"":""none""}";
      end if;

      Ada.Directories.Start_Search
        (Search, Get_Data_Dir, "*.dat",
         (Ada.Directories.Ordinary_File => True, others => False));

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Entry_Info);
         Count := Count + 1;
      end loop;

      Ada.Directories.End_Search (Search);

      return "{""keys"":" & Count'Image &
             ",""backend"":""" &
             (case Current_Backend is
                when File_Backend => "file",
                when CubsDB_Backend => "cubsdb",
                when SQLite_Backend => "sqlite") &
             """}";
   end Get_Stats;

end Storage;
