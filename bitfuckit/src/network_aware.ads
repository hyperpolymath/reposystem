-- SPDX-License-Identifier: PMPL-1.0
-- Network_Aware - Metered network detection and intelligent scheduling
-- Integrates with: complete-linux-internet-repair for self-healing

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Calendar; use Ada.Calendar;

package Network_Aware is

   -- Network connectivity states
   type Network_State is (
      Online,               -- Full connectivity
      Metered,              -- Connected but metered (mobile data, pay-per-use)
      Partial_Connectivity, -- Partial connectivity (DNS works, HTTPS fails)
      Offline,              -- No connectivity
      Unknown               -- Could not determine state
   );

   -- Operation priority levels
   type Operation_Priority is (
      Critical,     -- Must run immediately (auth, urgent ops)
      High,         -- Run if online, queue if metered
      Normal,       -- Run if online and not metered
      Low,          -- Only run on unmetered WiFi
      Background    -- Run when idle and on good connection
   );

   type Scheduled_Operation is record
      ID          : Natural := 0;
      Command     : Unbounded_String := Null_Unbounded_String;
      Priority    : Operation_Priority := Normal;
      Retry_Count : Natural := 0;
      Max_Retries : Natural := 3;
      Scheduled   : Time := Clock;
      Next_Retry  : Time := Clock;
      Last_Error  : Unbounded_String := Null_Unbounded_String;
   end record;

   -- Network state detection
   function Get_Network_State return Network_State;
   function Is_Metered return Boolean;
   function Is_Online return Boolean;
   function Get_Connection_Type return String;  -- "wifi", "ethernet", "cellular", etc.

   -- Scheduling
   procedure Schedule_Operation
     (Command  : String;
      Priority : Operation_Priority := Normal);

   procedure Process_Pending_Operations;
   function Pending_Operation_Count return Natural;
   procedure Clear_All_Pending;

   -- Self-healing integration
   procedure Attempt_Network_Repair;
   function Complete_Linux_Internet_Repair_Available return Boolean;

   -- Configuration
   procedure Set_Allow_On_Metered (Enabled : Boolean);
   procedure Set_Max_Background_Bandwidth_KBps (Limit : Natural);
   function Get_Allow_On_Metered return Boolean;

private
   Allow_Metered_Operations : Boolean := False;
   Max_Background_BW_KBps : Natural := 100;  -- 100 KB/s for background

end Network_Aware;
