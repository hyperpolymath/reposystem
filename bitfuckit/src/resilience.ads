-- SPDX-License-Identifier: PMPL-1.0
-- Resilience - Fault tolerance and self-healing patterns for bitfuckit
-- Implements: Retry, Circuit Breaker, Rate Limiting, Health Checks

with Ada.Real_Time; use Ada.Real_Time;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package Resilience is

   -- Retry configuration
   type Retry_Config is record
      Max_Attempts     : Positive := 3;
      Initial_Delay_Ms : Natural := 100;
      Max_Delay_Ms     : Natural := 10_000;
      Backoff_Factor   : Float := 2.0;
      Jitter           : Boolean := True;  -- Add randomness to prevent thundering herd
   end record;

   Default_Retry : constant Retry_Config := (
      Max_Attempts     => 3,
      Initial_Delay_Ms => 100,
      Max_Delay_Ms     => 10_000,
      Backoff_Factor   => 2.0,
      Jitter           => True
   );

   -- Circuit breaker states
   type Circuit_State is (Closed, Open, Half_Open);

   type Circuit_Breaker is record
      State              : Circuit_State := Closed;
      Failure_Count      : Natural := 0;
      Success_Count      : Natural := 0;
      Failure_Threshold  : Positive := 5;
      Success_Threshold  : Positive := 3;
      Reset_Timeout_Sec  : Duration := 30.0;
      Last_Failure_Time  : Time := Clock;
      Last_Error         : Unbounded_String := Null_Unbounded_String;
   end record;

   -- Rate limiter (token bucket algorithm)
   type Rate_Limiter is record
      Tokens           : Natural := 100;
      Max_Tokens       : Positive := 100;
      Refill_Rate      : Positive := 10;  -- tokens per second
      Last_Refill_Time : Time := Clock;
   end record;

   -- Health check result
   type Health_Status is (Healthy, Degraded, Unhealthy, Unknown);

   type Health_Check_Result is record
      Status      : Health_Status := Unknown;
      Message     : Unbounded_String := Null_Unbounded_String;
      Last_Check  : Time := Clock;
      Latency_Ms  : Natural := 0;
   end record;

   -- Circuit breaker operations
   procedure Record_Success (CB : in out Circuit_Breaker);
   procedure Record_Failure (CB : in out Circuit_Breaker; Error_Msg : String);
   function Can_Execute (CB : in Out Circuit_Breaker) return Boolean;
   function Get_State (CB : Circuit_Breaker) return Circuit_State;
   procedure Reset (CB : in out Circuit_Breaker);

   -- Rate limiter operations
   function Acquire_Token (RL : in out Rate_Limiter) return Boolean;
   procedure Wait_For_Token (RL : in Out Rate_Limiter);
   function Tokens_Available (RL : Rate_Limiter) return Natural;

   -- Retry helper
   function Calculate_Delay_Ms
     (Attempt : Positive;
      Config  : Retry_Config) return Natural;

   -- Health check
   function Check_API_Health return Health_Check_Result;
   function Check_Network_Health return Health_Check_Result;

   -- Self-healing actions
   procedure Clear_Credential_Cache;
   procedure Refresh_API_Token;
   procedure Reset_All_Circuit_Breakers;

   -- Global circuit breakers for different endpoints
   API_Circuit       : Circuit_Breaker;
   Auth_Circuit      : Circuit_Breaker;
   Network_Circuit   : Circuit_Breaker;

   -- Global rate limiter (Bitbucket: 1000 req/hr for authenticated)
   API_Rate_Limiter : Rate_Limiter := (
      Tokens           => 1000,
      Max_Tokens       => 1000,
      Refill_Rate      => 1,  -- ~1 per 3.6 sec for 1000/hr
      Last_Refill_Time => Clock
   );

end Resilience;
