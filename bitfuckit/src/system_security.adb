-- SPDX-License-Identifier: PMPL-1.0
-- System_Security implementation

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;
with GNAT.Expect; use GNAT.Expect;
with Ada.Directories;
with Ada.Text_IO;

package body System_Security is

   function Run_Command (Cmd : String) return String is
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
   begin
      begin
         Non_Blocking_Spawn
           (Pd,
            "/bin/sh",
            GNAT.OS_Lib.Argument_String_To_List ("-c " & Cmd).all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 5_000);
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);
      exception
         when others =>
            return "";
      end;

      return To_String (Output);
   end Run_Command;

   function Get_SELinux_Mode return SELinux_Mode is
      Result : constant String := Run_Command ("getenforce 2>/dev/null");
   begin
      if Index (To_Unbounded_String (Result), "Enforcing") > 0 then
         return Enforcing;
      elsif Index (To_Unbounded_String (Result), "Permissive") > 0 then
         return Permissive;
      elsif Index (To_Unbounded_String (Result), "Disabled") > 0 then
         return Disabled;
      else
         return Unknown;
      end if;
   end Get_SELinux_Mode;

   function Is_SELinux_Enforcing return Boolean is
   begin
      return Get_SELinux_Mode = Enforcing;
   end Is_SELinux_Enforcing;

   procedure Set_SELinux_Context (Path : String; Context : String) is
      Ret : Integer;
   begin
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/chcon",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("-t " & Context & " " & Path).all);
   end Set_SELinux_Context;

   procedure Apply_Bitfuckit_Contexts is
      Home : constant String := Run_Command ("echo $HOME");
      Data_Dir : constant String := Home & "/.local/share/bitfuckit";
      Config_Dir : constant String := Home & "/.config/bitfuckit";
   begin
      if not Is_SELinux_Enforcing then
         return;
      end if;

      -- Set contexts for data and config directories
      Set_SELinux_Context (Data_Dir, "user_home_t");
      Set_SELinux_Context (Config_Dir, "user_home_t");
   end Apply_Bitfuckit_Contexts;

   function Check_Bitfuckit_Contexts return Boolean is
      Result : constant String := Run_Command
        ("ls -Z ~/.local/share/bitfuckit 2>/dev/null | head -1");
   begin
      return Result'Length > 0 and then
             Index (To_Unbounded_String (Result), "user_home_t") > 0;
   end Check_Bitfuckit_Contexts;

   function Is_Firewalld_Running return Boolean is
      Result : constant String := Run_Command
        ("systemctl is-active firewalld 2>/dev/null");
   begin
      return Index (To_Unbounded_String (Result), "active") > 0;
   end Is_Firewalld_Running;

   function Get_Active_Zone return String is
      Result : constant String := Run_Command
        ("firewall-cmd --get-active-zones 2>/dev/null | head -1");
   begin
      return Result;
   end Get_Active_Zone;

   procedure Add_Bitfuckit_Service is
      Service_File : constant String := Get_Firewalld_Service_Path;
      File : Ada.Text_IO.File_Type;
      Ret : Integer;
   begin
      if not Is_Firewalld_Running then
         return;
      end if;

      -- Create service definition
      begin
         Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Service_File);
         Ada.Text_IO.Put_Line (File, "<?xml version=""1.0"" encoding=""utf-8""?>");
         Ada.Text_IO.Put_Line (File, "<service>");
         Ada.Text_IO.Put_Line (File, "  <short>bitfuckit</short>");
         Ada.Text_IO.Put_Line (File, "  <description>Bitbucket CLI tool network access</description>");
         Ada.Text_IO.Put_Line (File, "  <port protocol=""tcp"" port=""443""/>");
         Ada.Text_IO.Put_Line (File, "  <destination ipv4=""104.192.136.0/21""/>"); -- Atlassian
         Ada.Text_IO.Put_Line (File, "</service>");
         Ada.Text_IO.Close (File);
      exception
         when others => null;
      end;

      -- Add service to active zone
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--add-service=bitfuckit --permanent").all);

      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List ("--reload").all);
   end Add_Bitfuckit_Service;

   procedure Remove_Bitfuckit_Service is
      Ret : Integer;
   begin
      if not Is_Firewalld_Running then
         return;
      end if;

      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--remove-service=bitfuckit --permanent").all);

      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List ("--reload").all);
   end Remove_Bitfuckit_Service;

   procedure Allow_Bitbucket_API is
      Ret : Integer;
   begin
      -- Atlassian IP ranges for Bitbucket Cloud
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--add-rich-rule='rule family=ipv4 destination address=104.192.136.0/21 port port=443 protocol=tcp accept' --permanent").all);
   end Allow_Bitbucket_API;

   procedure Allow_Syncthing_Ports is
      Ret : Integer;
   begin
      -- Syncthing data transfer
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--add-port=22000/tcp --permanent").all);
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--add-port=22000/udp --permanent").all);
      -- Local discovery
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--add-port=21027/udp --permanent").all);
   end Allow_Syncthing_Ports;

   procedure Allow_OpenTimestamp_Calendars is
      Ret : Integer;
   begin
      -- OpenTimestamp calendar servers use HTTPS
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("--add-service=https --permanent").all);
   end Allow_OpenTimestamp_Calendars;

   procedure Deny_All_Except_Bitfuckit is
   begin
      -- This would be very restrictive, use with caution
      null;
   end Deny_All_Except_Bitfuckit;

   procedure Apply_Container_Security is
   begin
      -- For container/podman environments
      Apply_Bitfuckit_Contexts;
   end Apply_Container_Security;

   procedure Setup_Container_Firewall_Rules is
      Ret : Integer;
   begin
      if not Is_Firewalld_Running then
         return;
      end if;

      -- Allow container network access to Bitbucket
      Allow_Bitbucket_API;
      Allow_OpenTimestamp_Calendars;

      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/firewall-cmd",
         Args => GNAT.OS_Lib.Argument_String_To_List ("--reload").all);
   end Setup_Container_Firewall_Rules;

   function Verify_Container_Isolation return Boolean is
      Result : constant String := Run_Command
        ("podman inspect --format '{{.HostConfig.SecurityOpt}}' bitfuckit 2>/dev/null");
   begin
      return Index (To_Unbounded_String (Result), "label") > 0;
   end Verify_Container_Isolation;

   function Get_Security_Status return Security_Status is
      Status : Security_Status;
   begin
      Status.SELinux_Mode_Value := Get_SELinux_Mode;
      Status.SELinux_Enabled := Status.SELinux_Mode_Value /= Disabled and
                                Status.SELinux_Mode_Value /= Unknown;
      Status.Firewalld_Running := Is_Firewalld_Running;
      Status.Active_Zone := To_Unbounded_String (Get_Active_Zone);
      Status.Bitfuckit_Allowed := True;  -- TODO: Check actual rules

      return Status;
   end Get_Security_Status;

   procedure Harden_System is
   begin
      Apply_Bitfuckit_Contexts;
      Add_Bitfuckit_Service;
      Allow_Bitbucket_API;
      Allow_OpenTimestamp_Calendars;
   end Harden_System;

   procedure Relax_For_Development is
   begin
      Remove_Bitfuckit_Service;
   end Relax_For_Development;

   function Get_SELinux_Policy_Path return String is
   begin
      return "/etc/selinux/targeted/contexts/files/file_contexts.local";
   end Get_SELinux_Policy_Path;

   function Get_Firewalld_Service_Path return String is
   begin
      return "/etc/firewalld/services/bitfuckit.xml";
   end Get_Firewalld_Service_Path;

end System_Security;
