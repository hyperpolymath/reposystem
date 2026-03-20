-- SPDX-License-Identifier: PMPL-1.0
-- Security_Scan - Virus checking and vulnerability scanning
-- Integrates: ClamAV (local), VirusTotal API (optional cloud)

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Security_Scan is

   type Scan_Result_Status is (Clean, Infected, Error, Skipped);

   type Scan_Result is record
      Status      : Scan_Result_Status := Skipped;
      Threat_Name : Unbounded_String := Null_Unbounded_String;
      Message     : Unbounded_String := Null_Unbounded_String;
      Scanner     : Unbounded_String := Null_Unbounded_String;
   end record;

   -- ClamAV integration (requires clamscan or clamdscan)
   function ClamAV_Available return Boolean;
   function Scan_File_ClamAV (File_Path : String) return Scan_Result;
   function Scan_Directory_ClamAV (Dir_Path : String) return Scan_Result;

   -- VirusTotal API integration (requires API key)
   function VirusTotal_Configured return Boolean;
   procedure Configure_VirusTotal (API_Key : String);
   function Scan_File_VirusTotal (File_Path : String) return Scan_Result;
   function Scan_URL_VirusTotal (URL : String) return Scan_Result;

   -- Combined scanning (uses available scanners)
   function Scan_File (File_Path : String) return Scan_Result;
   function Scan_Repository (Repo_Path : String) return Scan_Result;

   -- Configuration
   procedure Set_Scan_On_Clone (Enabled : Boolean);
   procedure Set_Scan_On_Pull (Enabled : Boolean);
   function Get_Scan_On_Clone return Boolean;
   function Get_Scan_On_Pull return Boolean;

private
   VT_API_Key : Unbounded_String := Null_Unbounded_String;
   Scan_On_Clone_Enabled : Boolean := False;
   Scan_On_Pull_Enabled : Boolean := False;

end Security_Scan;
