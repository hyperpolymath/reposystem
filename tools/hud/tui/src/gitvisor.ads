-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

--  Gitvisor - Root package
--
--  Provides common types and constants for the TUI.

package Gitvisor is
   pragma Pure;

   --  Version information
   Version_Major : constant := 0;
   Version_Minor : constant := 1;
   Version_Patch : constant := 0;

   --  Platform types
   type Platform_Type is (GitHub, GitLab, Gitea, Codeberg);

   --  Maximum lengths for strings (SPARK friendly)
   Max_Name_Length        : constant := 256;
   Max_Description_Length : constant := 4096;
   Max_URL_Length         : constant := 2048;

   --  Bounded string types
   subtype Name_String is String (1 .. Max_Name_Length);
   subtype Description_String is String (1 .. Max_Description_Length);
   subtype URL_String is String (1 .. Max_URL_Length);

end Gitvisor;
