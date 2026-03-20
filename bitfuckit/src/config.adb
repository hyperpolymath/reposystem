-- SPDX-License-Identifier: PMPL-1.0-or-later
-- Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

with Ada.Environment_Variables;
with Ada.Directories;
with Ada.Text_IO;
with Ada.IO_Exceptions;

package body Config is

   function Get_Config_Dir return String is
      Home : constant String := Ada.Environment_Variables.Value ("HOME");
   begin
      return Home & "/.config/bitfuckit";
   end Get_Config_Dir;

   function Get_Config_File return String is
   begin
      return Get_Config_Dir & "/config";
   end Get_Config_File;

   function Load_Credentials return Credentials is
      File : Ada.Text_IO.File_Type;
      Result : Credentials := No_Credentials;
   begin
      if not Ada.Directories.Exists (Get_Config_File) then
         return No_Credentials;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Get_Config_File);

      if not Ada.Text_IO.End_Of_File (File) then
         Result.Username := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
      end if;

      if not Ada.Text_IO.End_Of_File (File) then
         Result.App_Password := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
      end if;

      if not Ada.Text_IO.End_Of_File (File) then
         Result.Workspace := To_Unbounded_String (Ada.Text_IO.Get_Line (File));
      end if;

      Ada.Text_IO.Close (File);
      return Result;

   exception
      when Ada.IO_Exceptions.Name_Error =>
         return No_Credentials;
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return No_Credentials;
   end Load_Credentials;

   procedure Save_Credentials (Creds : Credentials) is
      File : Ada.Text_IO.File_Type;
      Dir : constant String := Get_Config_Dir;
   begin
      if not Ada.Directories.Exists (Dir) then
         Ada.Directories.Create_Path (Dir);
      end if;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Get_Config_File);
      Ada.Text_IO.Put_Line (File, To_String (Creds.Username));
      Ada.Text_IO.Put_Line (File, To_String (Creds.App_Password));
      Ada.Text_IO.Put_Line (File, To_String (Creds.Workspace));
      Ada.Text_IO.Close (File);
   end Save_Credentials;

   function Has_Credentials return Boolean is
      Creds : constant Credentials := Load_Credentials;
   begin
      return Length (Creds.Username) > 0
         and then Length (Creds.App_Password) > 0
         and then Length (Creds.Workspace) > 0;
   end Has_Credentials;

end Config;
