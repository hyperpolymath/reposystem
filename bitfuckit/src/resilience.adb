-- SPDX-License-Identifier: PMPL-1.0
-- Resilience implementation - Fault tolerance patterns

with Ada.Numerics.Float_Random;
with GNAT.OS_Lib;
with Ada.Text_IO;

package body Resilience is

   Gen : Ada.Numerics.Float_Random.Generator;

   procedure Record_Success (CB : in out Circuit_Breaker) is
   begin
      case CB.State is
         when Closed =>
            CB.Failure_Count := 0;

         when Half_Open =>
            CB.Success_Count := CB.Success_Count + 1;
            if CB.Success_Count >= CB.Success_Threshold then
               CB.State := Closed;
               CB.Failure_Count := 0;
               CB.Success_Count := 0;
            end if;

         when Open =>
            null;  -- Should not happen
      end case;
   end Record_Success;

   procedure Record_Failure (CB : in Out Circuit_Breaker; Error_Msg : String) is
   begin
      CB.Last_Failure_Time := Clock;
      CB.Last_Error := To_Unbounded_String (Error_Msg);

      case CB.State is
         when Closed =>
            CB.Failure_Count := CB.Failure_Count + 1;
            if CB.Failure_Count >= CB.Failure_Threshold then
               CB.State := Open;
            end if;

         when Half_Open =>
            CB.State := Open;
            CB.Success_Count := 0;

         when Open =>
            null;  -- Already open
      end case;
   end Record_Failure;

   function Can_Execute (CB : in Out Circuit_Breaker) return Boolean is
      Now : constant Time := Clock;
      Elapsed : Duration;
   begin
      case CB.State is
         when Closed =>
            return True;

         when Open =>
            Elapsed := To_Duration (Now - CB.Last_Failure_Time);
            if Elapsed >= CB.Reset_Timeout_Sec then
               CB.State := Half_Open;
               CB.Success_Count := 0;
               return True;
            else
               return False;
            end if;

         when Half_Open =>
            return True;
      end case;
   end Can_Execute;

   function Get_State (CB : Circuit_Breaker) return Circuit_State is
   begin
      return CB.State;
   end Get_State;

   procedure Reset (CB : in Out Circuit_Breaker) is
   begin
      CB.State := Closed;
      CB.Failure_Count := 0;
      CB.Success_Count := 0;
      CB.Last_Error := Null_Unbounded_String;
   end Reset;

   function Acquire_Token (RL : in Out Rate_Limiter) return Boolean is
      Now : constant Time := Clock;
      Elapsed_Sec : constant Duration := To_Duration (Now - RL.Last_Refill_Time);
      New_Tokens : Natural;
   begin
      -- Refill tokens based on elapsed time
      if Elapsed_Sec >= 1.0 then
         New_Tokens := Natural (Float'Floor (Float (Elapsed_Sec) *
                                             Float (RL.Refill_Rate)));
         RL.Tokens := Natural'Min (RL.Tokens + New_Tokens, RL.Max_Tokens);
         RL.Last_Refill_Time := Now;
      end if;

      -- Try to acquire a token
      if RL.Tokens > 0 then
         RL.Tokens := RL.Tokens - 1;
         return True;
      else
         return False;
      end if;
   end Acquire_Token;

   procedure Wait_For_Token (RL : in Out Rate_Limiter) is
   begin
      while not Acquire_Token (RL) loop
         delay 0.1;  -- Wait 100ms and try again
      end loop;
   end Wait_For_Token;

   function Tokens_Available (RL : Rate_Limiter) return Natural is
   begin
      return RL.Tokens;
   end Tokens_Available;

   function Calculate_Delay_Ms
     (Attempt : Positive;
      Config  : Retry_Config) return Natural
   is
      Base_Delay : Natural;
      Jitter_Factor : Float;
   begin
      -- Exponential backoff: delay = initial * factor^(attempt-1)
      Base_Delay := Natural (Float (Config.Initial_Delay_Ms) *
                             (Config.Backoff_Factor ** (Attempt - 1)));

      -- Cap at maximum delay
      Base_Delay := Natural'Min (Base_Delay, Config.Max_Delay_Ms);

      -- Add jitter (0.5 to 1.5 multiplier)
      if Config.Jitter then
         Ada.Numerics.Float_Random.Reset (Gen);
         Jitter_Factor := 0.5 + Ada.Numerics.Float_Random.Random (Gen);
         Base_Delay := Natural (Float (Base_Delay) * Jitter_Factor);
      end if;

      return Base_Delay;
   end Calculate_Delay_Ms;

   function Check_API_Health return Health_Check_Result is
      Result : Health_Check_Result;
      Start_Time : constant Time := Clock;
      Spawn_Result : Integer;
      Args : GNAT.OS_Lib.Argument_List_Access;
   begin
      -- Simple health check: HEAD request to Bitbucket API
      Args := GNAT.OS_Lib.Argument_String_To_List
        ("-s -o /dev/null -w %{http_code} -I --max-time 5 " &
         "https://api.bitbucket.org/2.0/");

      Spawn_Result := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/curl",
         Args => Args.all);

      Result.Last_Check := Clock;
      Result.Latency_Ms := Natural (To_Duration (Clock - Start_Time) * 1000.0);

      if Spawn_Result = 0 then
         Result.Status := Healthy;
         Result.Message := To_Unbounded_String ("API responding normally");
      else
         Result.Status := Unhealthy;
         Result.Message := To_Unbounded_String ("API not responding");
      end if;

      return Result;
   end Check_API_Health;

   function Check_Network_Health return Health_Check_Result is
      Result : Health_Check_Result;
      Start_Time : constant Time := Clock;
      Spawn_Result : Integer;
      Args : GNAT.OS_Lib.Argument_List_Access;
   begin
      -- Ping bitbucket.org to check network connectivity
      Args := GNAT.OS_Lib.Argument_String_To_List
        ("-c 1 -W 2 bitbucket.org");

      Spawn_Result := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/ping",
         Args => Args.all);

      Result.Last_Check := Clock;
      Result.Latency_Ms := Natural (To_Duration (Clock - Start_Time) * 1000.0);

      if Spawn_Result = 0 then
         Result.Status := Healthy;
         Result.Message := To_Unbounded_String ("Network connectivity OK");
      else
         Result.Status := Unhealthy;
         Result.Message := To_Unbounded_String ("Network connectivity failed");
      end if;

      return Result;
   end Check_Network_Health;

   procedure Clear_Credential_Cache is
   begin
      -- Placeholder: clear any cached credentials in memory
      null;
   end Clear_Credential_Cache;

   procedure Refresh_API_Token is
   begin
      -- Placeholder: re-authenticate if using OAuth tokens
      null;
   end Refresh_API_Token;

   procedure Reset_All_Circuit_Breakers is
   begin
      Reset (API_Circuit);
      Reset (Auth_Circuit);
      Reset (Network_Circuit);
   end Reset_All_Circuit_Breakers;

end Resilience;
