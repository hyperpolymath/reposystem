-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)
-- Bitbucket API client for bitfuckit

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Config;

package Bitbucket_API is

   type API_Result is record
      Success : Boolean;
      Message : Unbounded_String;
      Data : Unbounded_String;
   end record;

   function Create_Repo
     (Creds : Config.Credentials;
      Name : String;
      Is_Private : Boolean := False;
      Description : String := "") return API_Result;

   function Delete_Repo
     (Creds : Config.Credentials;
      Name : String) return API_Result;

   function List_Repos
     (Creds : Config.Credentials) return API_Result;

   function Get_Repo
     (Creds : Config.Credentials;
      Name : String) return API_Result;

   function Repo_Exists
     (Creds : Config.Credentials;
      Name : String) return Boolean;

   function List_Pull_Requests
     (Creds : Config.Credentials;
      Repo_Name : String;
      State : String := "OPEN") return API_Result;
   --  State: OPEN, MERGED, DECLINED, SUPERSEDED, or empty for all

end Bitbucket_API;
