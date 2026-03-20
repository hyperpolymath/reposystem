-- SPDX-License-Identifier: PMPL-1.0
-- Security_Scan implementation

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;
with GNAT.Expect; use GNAT.Expect;
with Ada.Directories;
with Ada.Text_IO;

package body Security_Scan is

   function ClamAV_Available return Boolean is
      Ret : Integer;
   begin
      -- Check if clamdscan (daemon) or clamscan is available
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/which",
         Args => GNAT.OS_Lib.Argument_String_To_List ("clamdscan").all);
      if Ret = 0 then
         return True;
      end if;

      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/which",
         Args => GNAT.OS_Lib.Argument_String_To_List ("clamscan").all);
      return Ret = 0;
   end ClamAV_Available;

   function Get_Scanner_Path return String is
      Clamdscan_Path : GNAT.OS_Lib.String_Access;
   begin
      Clamdscan_Path := GNAT.OS_Lib.Locate_Exec_On_Path ("clamdscan");
      if Clamdscan_Path /= null then
         return "clamdscan";
      else
         return "clamscan";
      end if;
   end Get_Scanner_Path;

   function Scan_File_ClamAV (File_Path : String) return Scan_Result is
      Result : Scan_Result;
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Scanner_Path : constant String := Get_Scanner_Path;
   begin
      if not ClamAV_Available then
         Result.Status := Skipped;
         Result.Message := To_Unbounded_String ("ClamAV not installed");
         return Result;
      end if;

      if not Ada.Directories.Exists (File_Path) then
         Result.Status := Error;
         Result.Message := To_Unbounded_String ("File not found: " & File_Path);
         return Result;
      end if;

      Result.Scanner := To_Unbounded_String ("ClamAV");

      begin
         Non_Blocking_Spawn
           (Pd,
            Scanner_Path,
            GNAT.OS_Lib.Argument_String_To_List
              ("--no-summary " & File_Path).all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 60_000);
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);

         -- Check output for infection
         if Index (Output, "FOUND") > 0 then
            Result.Status := Infected;
            -- Extract threat name (format: "file: ThreatName FOUND")
            declare
               Colon_Pos : constant Natural := Index (Output, ": ");
               Found_Pos : constant Natural := Index (Output, " FOUND");
            begin
               if Colon_Pos > 0 and Found_Pos > Colon_Pos then
                  Result.Threat_Name := To_Unbounded_String
                    (Slice (Output, Colon_Pos + 2, Found_Pos - 1));
               end if;
            end;
            Result.Message := To_Unbounded_String ("Threat detected!");
         elsif Index (Output, "OK") > 0 then
            Result.Status := Clean;
            Result.Message := To_Unbounded_String ("No threats found");
         else
            Result.Status := Error;
            Result.Message := Output;
         end if;

      exception
         when others =>
            Result.Status := Error;
            Result.Message := To_Unbounded_String ("ClamAV scan failed");
      end;

      return Result;
   end Scan_File_ClamAV;

   function Scan_Directory_ClamAV (Dir_Path : String) return Scan_Result is
      Result : Scan_Result;
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
   begin
      if not ClamAV_Available then
         Result.Status := Skipped;
         Result.Message := To_Unbounded_String ("ClamAV not installed");
         return Result;
      end if;

      Result.Scanner := To_Unbounded_String ("ClamAV");

      begin
         Non_Blocking_Spawn
           (Pd,
            "clamscan",
            GNAT.OS_Lib.Argument_String_To_List
              ("-r --no-summary " & Dir_Path).all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 300_000);  -- 5 min timeout
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);

         if Index (Output, "FOUND") > 0 then
            Result.Status := Infected;
            Result.Message := To_Unbounded_String ("Threats detected in directory");
         else
            Result.Status := Clean;
            Result.Message := To_Unbounded_String ("Directory scan clean");
         end if;

      exception
         when others =>
            Result.Status := Error;
            Result.Message := To_Unbounded_String ("Directory scan failed");
      end;

      return Result;
   end Scan_Directory_ClamAV;

   function VirusTotal_Configured return Boolean is
   begin
      return Length (VT_API_Key) > 0;
   end VirusTotal_Configured;

   procedure Configure_VirusTotal (API_Key : String) is
   begin
      VT_API_Key := To_Unbounded_String (API_Key);
   end Configure_VirusTotal;

   function Scan_File_VirusTotal (File_Path : String) return Scan_Result is
      Result : Scan_Result;
      -- Note: Full implementation would use curl to POST file to VT API
      -- and poll for results. This is a placeholder.
   begin
      Result.Scanner := To_Unbounded_String ("VirusTotal");

      if not VirusTotal_Configured then
         Result.Status := Skipped;
         Result.Message := To_Unbounded_String
           ("VirusTotal API key not configured. Set VIRUSTOTAL_API_KEY.");
         return Result;
      end if;

      if not Ada.Directories.Exists (File_Path) then
         Result.Status := Error;
         Result.Message := To_Unbounded_String ("File not found");
         return Result;
      end if;

      -- TODO: Implement actual VT API call
      -- POST to https://www.virustotal.com/api/v3/files
      -- Poll GET /analyses/{id} until complete

      Result.Status := Skipped;
      Result.Message := To_Unbounded_String
        ("VirusTotal scanning not yet implemented");
      return Result;
   end Scan_File_VirusTotal;

   function Scan_URL_VirusTotal (URL : String) return Scan_Result is
      Result : Scan_Result;
   begin
      Result.Scanner := To_Unbounded_String ("VirusTotal");

      if not VirusTotal_Configured then
         Result.Status := Skipped;
         Result.Message := To_Unbounded_String ("VirusTotal not configured");
         return Result;
      end if;

      -- TODO: Implement URL scanning
      -- POST to https://www.virustotal.com/api/v3/urls

      Result.Status := Skipped;
      Result.Message := To_Unbounded_String ("URL scanning not implemented");
      return Result;
   end Scan_URL_VirusTotal;

   function Scan_File (File_Path : String) return Scan_Result is
      Result : Scan_Result;
   begin
      -- Try ClamAV first (local, fast)
      if ClamAV_Available then
         Result := Scan_File_ClamAV (File_Path);
         if Result.Status = Clean or Result.Status = Infected then
            return Result;
         end if;
      end if;

      -- Fall back to VirusTotal if configured
      if VirusTotal_Configured then
         return Scan_File_VirusTotal (File_Path);
      end if;

      -- No scanners available
      Result.Status := Skipped;
      Result.Message := To_Unbounded_String
        ("No security scanners available. Install ClamAV or configure VirusTotal.");
      return Result;
   end Scan_File;

   function Scan_Repository (Repo_Path : String) return Scan_Result is
   begin
      if ClamAV_Available then
         return Scan_Directory_ClamAV (Repo_Path);
      else
         declare
            Result : Scan_Result;
         begin
            Result.Status := Skipped;
            Result.Message := To_Unbounded_String
              ("ClamAV required for repository scanning");
            return Result;
         end;
      end if;
   end Scan_Repository;

   procedure Set_Scan_On_Clone (Enabled : Boolean) is
   begin
      Scan_On_Clone_Enabled := Enabled;
   end Set_Scan_On_Clone;

   procedure Set_Scan_On_Pull (Enabled : Boolean) is
   begin
      Scan_On_Pull_Enabled := Enabled;
   end Set_Scan_On_Pull;

   function Get_Scan_On_Clone return Boolean is
   begin
      return Scan_On_Clone_Enabled;
   end Get_Scan_On_Clone;

   function Get_Scan_On_Pull return Boolean is
   begin
      return Scan_On_Pull_Enabled;
   end Get_Scan_On_Pull;

end Security_Scan;
