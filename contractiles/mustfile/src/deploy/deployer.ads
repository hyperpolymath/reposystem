-- deployer.ads
-- Container deployment for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Must_Types; use Must_Types;

package Deployer is

   --  Deploy target types
   type Deploy_Target_Type is (Target_Container, Target_Local);

   --  Check if Containerfile exists
   function Containerfile_Exists return Boolean;

   --  Get the Containerfile path
   function Get_Containerfile_Path return String;

   --  Deploy the project
   procedure Deploy
     (Config  : Mustfile_Config;
      Target  : String;
      Tag     : String;
      Push    : Boolean;
      Dry_Run : Boolean;
      Verbose : Boolean);

   --  Build container image
   procedure Build_Container
     (Project_Name : String;
      Tag          : String;
      Dry_Run      : Boolean;
      Verbose      : Boolean);

   --  Push container image to registry
   procedure Push_Container
     (Project_Name : String;
      Tag          : String;
      Registry     : String;
      Dry_Run      : Boolean;
      Verbose      : Boolean);

   --  Deploy error exception
   Deploy_Error : exception;

end Deployer;
