-- SPDX-License-Identifier: PMPL-1.0
-- GraphQL Server for bitfuckit
-- Fire-and-Fuck-GET (and more) with Bitbucket
--
-- Exposes ALL CLI functionality via GraphQL API.
-- Everything you can do offline, you can do via this API.

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package GraphQL_Server
   with SPARK_Mode => On
is
   -- Server configuration
   type Server_Config is record
      Port            : Positive := 4000;
      Host            : Unbounded_String := To_Unbounded_String ("127.0.0.1");
      Enable_Playground : Boolean := False;
      Enable_Introspection : Boolean := True;
      Max_Depth       : Positive := 10;
      Timeout_Seconds : Positive := 30;
   end record;

   -- Server state
   type Server_State is (Stopped, Starting, Running, Stopping, Error);

   -- Result type for operations
   type GraphQL_Result is record
      Success : Boolean;
      Data    : Unbounded_String;
      Errors  : Unbounded_String;
   end record;

   -- Server operations
   procedure Initialize (Config : Server_Config)
      with Global => null;

   procedure Start
      with Global => null,
           Pre => Get_State = Stopped;

   procedure Stop
      with Global => null,
           Pre => Get_State = Running;

   function Get_State return Server_State
      with Global => null;

   -- Query execution
   function Execute_Query (Query : String; Variables : String := "{}")
      return GraphQL_Result
      with Global => null;

   -- Schema introspection
   function Get_Schema return String
      with Global => null;

   -- Health check
   function Is_Healthy return Boolean
      with Global => null;

private
   Current_State : Server_State := Stopped;
   Current_Config : Server_Config;

end GraphQL_Server;
