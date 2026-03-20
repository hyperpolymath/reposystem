-- SPDX-License-Identifier: PMPL-1.0
-- System_Security - SELinux and Firewalld integration for bitfuckit
-- Provides container boundary security and network access control

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

package System_Security is

   -- SELinux modes
   type SELinux_Mode is (Enforcing, Permissive, Disabled, Unknown);

   -- Firewall zone types
   type Firewall_Zone is (
      Drop,         -- Drop all incoming
      Block,        -- Reject incoming with icmp
      Public,       -- Default for untrusted networks
      External,     -- For NAT/masquerading
      Internal,     -- Trusted internal network
      Work,         -- Work network
      Home,         -- Home network
      Trusted       -- Accept all
   );

   type Security_Status is record
      SELinux_Enabled    : Boolean := False;
      SELinux_Mode_Value : SELinux_Mode := Unknown;
      Firewalld_Running  : Boolean := False;
      Active_Zone        : Unbounded_String := Null_Unbounded_String;
      Bitfuckit_Allowed  : Boolean := False;
   end record;

   -- SELinux operations
   function Get_SELinux_Mode return SELinux_Mode;
   function Is_SELinux_Enforcing return Boolean;
   procedure Set_SELinux_Context (Path : String; Context : String);

   -- Bitfuckit-specific SELinux contexts
   procedure Apply_Bitfuckit_Contexts;
   function Check_Bitfuckit_Contexts return Boolean;

   -- Firewalld operations
   function Is_Firewalld_Running return Boolean;
   function Get_Active_Zone return String;
   procedure Add_Bitfuckit_Service;
   procedure Remove_Bitfuckit_Service;

   -- Rich rules for API access
   procedure Allow_Bitbucket_API;
   procedure Allow_Syncthing_Ports;
   procedure Allow_OpenTimestamp_Calendars;
   procedure Deny_All_Except_Bitfuckit;

   -- Container-specific security
   procedure Apply_Container_Security;
   procedure Setup_Container_Firewall_Rules;
   function Verify_Container_Isolation return Boolean;

   -- Overall status
   function Get_Security_Status return Security_Status;
   procedure Harden_System;
   procedure Relax_For_Development;

   -- Configuration file paths
   function Get_SELinux_Policy_Path return String;
   function Get_Firewalld_Service_Path return String;

private
   -- Default ports
   Bitbucket_HTTPS_Port : constant := 443;
   Syncthing_TCP_Port   : constant := 22000;
   Syncthing_UDP_Port   : constant := 22000;
   Syncthing_Discovery  : constant := 21027;

end System_Security;
