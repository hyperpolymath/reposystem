-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

package body Gitvisor.API is

   Connected : Boolean := False;
   Endpoint  : URL_String := (others => ' ');
   Endpoint_Len : Natural := 0;

   procedure Initialize (Config : in Gitvisor.Config.Settings) is
   begin
      Endpoint := Config.API_Endpoint;
      Endpoint_Len := Config.Endpoint_Length;
      Connected := True;
      --  TODO: Actual HTTP connection setup
   end Initialize;

   procedure Finalize is
   begin
      Connected := False;
   end Finalize;

   function Is_Connected return Boolean is
   begin
      return Connected;
   end Is_Connected;

   procedure Fetch_Repositories
     (Platform : Platform_Type;
      Repos    : out Repository_Array;
      Count    : out Natural)
   is
      pragma Unreferenced (Platform);
   begin
      --  TODO: GraphQL query to backend
      Count := 0;
      for I in Repos'Range loop
         Repos (I) := (others => <>);
      end loop;
   end Fetch_Repositories;

   procedure Fetch_Issues
     (Platform : Platform_Type;
      Owner    : String;
      Repo     : String;
      Issues   : out Issue_Array;
      Count    : out Natural)
   is
      pragma Unreferenced (Platform, Owner, Repo);
   begin
      --  TODO: GraphQL query to backend
      Count := 0;
      for I in Issues'Range loop
         Issues (I) := (others => <>);
      end loop;
   end Fetch_Issues;

end Gitvisor.API;
