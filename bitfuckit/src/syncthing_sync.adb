-- SPDX-License-Identifier: PMPL-1.0
-- Syncthing_Sync implementation

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;
with GNAT.Expect; use GNAT.Expect;
with Ada.Text_IO;

package body Syncthing_Sync is

   function Run_Curl_To_Syncthing
     (Endpoint : String;
      Method   : String := "GET";
      Data     : String := "") return Unbounded_String
   is
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Args : constant String :=
         "-s -X " & Method &
         " -H ""X-API-Key: " & To_String (ST_API_Key) & """ " &
         (if Data'Length > 0
          then "-H ""Content-Type: application/json"" -d '" & Data & "' "
          else "") &
         To_String (ST_API_URL) & "/rest/" & Endpoint;
   begin
      begin
         Non_Blocking_Spawn
           (Pd,
            "/usr/bin/curl",
            GNAT.OS_Lib.Argument_String_To_List (Args).all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 10_000);
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);
      exception
         when others =>
            Output := To_Unbounded_String ("ERROR: Could not connect to Syncthing");
      end;

      return Output;
   end Run_Curl_To_Syncthing;

   procedure Configure_Syncthing
     (API_Key   : String;
      API_URL   : String := "http://127.0.0.1:8384")
   is
   begin
      ST_API_Key := To_Unbounded_String (API_Key);
      ST_API_URL := To_Unbounded_String (API_URL);
      Configured := True;
   end Configure_Syncthing;

   function Is_Syncthing_Configured return Boolean is
   begin
      return Configured and Length (ST_API_Key) > 0;
   end Is_Syncthing_Configured;

   function Is_Syncthing_Running return Boolean is
      Result : Unbounded_String;
   begin
      if not Is_Syncthing_Configured then
         return False;
      end if;

      Result := Run_Curl_To_Syncthing ("system/ping");
      return Index (Result, """pong""") > 0;
   end Is_Syncthing_Running;

   procedure Setup_Bitfuckit_Folder
     (Folder_Path : String := "~/.local/share/bitfuckit")
   is
      Config : constant String :=
         "{""id"":""bitfuckit-data""," &
         """label"":""Bitfuckit Data""," &
         """path"":""" & Folder_Path & """," &
         """type"":""sendreceive""," &
         """rescanIntervalS"":60}";
      Result : Unbounded_String;
   begin
      Result := Run_Curl_To_Syncthing ("config/folders", "POST", Config);
   end Setup_Bitfuckit_Folder;

   function Get_Sync_Status return Sync_Info is
      Info : Sync_Info;
      Result : Unbounded_String;
   begin
      if not Is_Syncthing_Running then
         Info.Status := (if Is_Syncthing_Configured
                         then Disconnected
                         else Not_Configured);
         return Info;
      end if;

      Result := Run_Curl_To_Syncthing ("db/status?folder=bitfuckit-data");

      if Index (Result, "errors") > 0 then
         Info.Status := Not_Configured;
         Info.Message := To_Unbounded_String ("Folder not found");
      elsif Index (Result, """state"":""idle""") > 0 then
         Info.Status := Synced;
      elsif Index (Result, """state"":""syncing""") > 0 then
         Info.Status := Syncing;
      elsif Index (Result, "conflict") > 0 then
         Info.Status := Conflict;
      else
         Info.Status := Out_Of_Sync;
      end if;

      return Info;
   end Get_Sync_Status;

   procedure Force_Sync is
      Result : Unbounded_String;
   begin
      Result := Run_Curl_To_Syncthing
        ("db/scan?folder=bitfuckit-data", "POST");
   end Force_Sync;

   procedure Rescan_Folder is
   begin
      Force_Sync;
   end Rescan_Folder;

   procedure Accept_Local_Version (File_Path : String) is
      Result : Unbounded_String;
   begin
      -- Syncthing doesn't have direct API for this, would need file ops
      null;
   end Accept_Local_Version;

   procedure Accept_Remote_Version (File_Path : String) is
      Result : Unbounded_String;
   begin
      -- Syncthing doesn't have direct API for this, would need file ops
      null;
   end Accept_Remote_Version;

   function Get_Conflict_Files return String is
      Result : Unbounded_String;
   begin
      Result := Run_Curl_To_Syncthing ("db/localchanged?folder=bitfuckit-data");
      return To_String (Result);
   end Get_Conflict_Files;

   procedure Add_Device (Device_ID : String; Name : String := "") is
      Device_Name : constant String :=
         (if Name'Length > 0 then Name else "bitfuckit-peer");
      Config : constant String :=
         "{""deviceID"":""" & Device_ID & """," &
         """name"":""" & Device_Name & """}";
      Result : Unbounded_String;
   begin
      Result := Run_Curl_To_Syncthing ("config/devices", "POST", Config);
   end Add_Device;

   procedure Remove_Device (Device_ID : String) is
      Result : Unbounded_String;
   begin
      Result := Run_Curl_To_Syncthing
        ("config/devices/" & Device_ID, "DELETE");
   end Remove_Device;

   function List_Connected_Devices return String is
      Result : Unbounded_String;
   begin
      Result := Run_Curl_To_Syncthing ("system/connections");
      return To_String (Result);
   end List_Connected_Devices;

   procedure Sync_Credentials is
   begin
      Force_Sync;
   end Sync_Credentials;

   procedure Sync_Settings is
   begin
      Force_Sync;
   end Sync_Settings;

end Syncthing_Sync;
