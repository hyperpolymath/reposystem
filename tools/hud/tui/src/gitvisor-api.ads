-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

--  Gitvisor.API - Backend API client
--
--  Communicates with the Gitvisor Elixir backend via GraphQL.

with Gitvisor.Config;

package Gitvisor.API is

   --  Initialize API connection
   procedure Initialize (Config : in Gitvisor.Config.Settings);

   --  Clean up API connection
   procedure Finalize;

   --  Check if connected
   function Is_Connected return Boolean;

   --  Repository operations
   type Repository_Info is record
      ID          : String (1 .. 64) := (others => ' ');
      ID_Length   : Natural := 0;
      Name        : Name_String := (others => ' ');
      Name_Length : Natural := 0;
      Owner       : Name_String := (others => ' ');
      Owner_Length : Natural := 0;
      Platform    : Platform_Type := GitHub;
      Stars       : Natural := 0;
      Is_Private  : Boolean := False;
   end record;

   type Repository_Array is array (Positive range <>) of Repository_Info;

   --  Fetch repositories for current user
   procedure Fetch_Repositories
     (Platform : Platform_Type;
      Repos    : out Repository_Array;
      Count    : out Natural);

   --  Issue operations
   type Issue_Info is record
      ID           : String (1 .. 64) := (others => ' ');
      ID_Length    : Natural := 0;
      Number       : Positive := 1;
      Title        : Name_String := (others => ' ');
      Title_Length : Natural := 0;
      State        : String (1 .. 16) := (others => ' ');
      State_Length : Natural := 0;
   end record;

   type Issue_Array is array (Positive range <>) of Issue_Info;

   --  Fetch issues for a repository
   procedure Fetch_Issues
     (Platform : Platform_Type;
      Owner    : String;
      Repo     : String;
      Issues   : out Issue_Array;
      Count    : out Natural);

end Gitvisor.API;
