-- deployer.adb
-- Container deployment for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Text_IO;           use Ada.Text_IO;
with Ada.Directories;       use Ada.Directories;
with GNAT.OS_Lib;           use GNAT.OS_Lib;

package body Deployer is

   Containerfile_Name : constant String := "Containerfile";

   function Containerfile_Exists return Boolean is
   begin
      return Exists (Containerfile_Name);
   end Containerfile_Exists;

   function Get_Containerfile_Path return String is
   begin
      return Containerfile_Name;
   end Get_Containerfile_Path;

   procedure Run_Command
     (Command : String;
      Args    : Argument_List_Access;
      Dry_Run : Boolean;
      Verbose : Boolean)
   is
      Success : Boolean;
   begin
      if Verbose or Dry_Run then
         Put ("  $ " & Command);
         for I in Args'Range loop
            Put (" " & Args (I).all);
         end loop;
         New_Line;
      end if;

      if Dry_Run then
         return;
      end if;

      Spawn
        (Program_Name => Command,
         Args         => Args.all,
         Success      => Success);

      if not Success then
         raise Deploy_Error with "Command failed: " & Command;
      end if;
   end Run_Command;

   procedure Build_Container
     (Project_Name : String;
      Tag          : String;
      Dry_Run      : Boolean;
      Verbose      : Boolean)
   is
      Actual_Tag : constant String :=
        (if Tag'Length > 0 then Tag else "latest");
      Image_Name : constant String :=
        Project_Name & ":" & Actual_Tag;
      Args : Argument_List_Access;
   begin
      Put_Line ("Building container image: " & Image_Name);

      if not Containerfile_Exists then
         raise Deploy_Error with "Containerfile not found";
      end if;

      --  podman build -t <name>:<tag> -f Containerfile .
      Args := new Argument_List (1 .. 5);
      Args (1) := new String'("build");
      Args (2) := new String'("-t");
      Args (3) := new String'(Image_Name);
      Args (4) := new String'("-f");
      Args (5) := new String'(Containerfile_Name);

      declare
         Dot_Args : Argument_List_Access := new Argument_List (1 .. 6);
      begin
         Dot_Args (1 .. 5) := Args (1 .. 5);
         Dot_Args (6) := new String'(".");

         Run_Command ("podman", Dot_Args, Dry_Run, Verbose);

         --  Free memory
         for I in Dot_Args'Range loop
            Free (Dot_Args (I));
         end loop;
         Free (Dot_Args);
      end;

      if not Dry_Run then
         Put_Line ("Container image built successfully: " & Image_Name);
      end if;
   end Build_Container;

   procedure Push_Container
     (Project_Name : String;
      Tag          : String;
      Registry     : String;
      Dry_Run      : Boolean;
      Verbose      : Boolean)
   is
      Actual_Tag : constant String :=
        (if Tag'Length > 0 then Tag else "latest");
      Local_Image : constant String := Project_Name & ":" & Actual_Tag;
      Remote_Image : constant String :=
        Registry & "/" & Project_Name & ":" & Actual_Tag;
      Args : Argument_List_Access;
   begin
      Put_Line ("Pushing container image to registry...");

      --  Tag for registry: podman tag <local> <remote>
      Args := new Argument_List (1 .. 3);
      Args (1) := new String'("tag");
      Args (2) := new String'(Local_Image);
      Args (3) := new String'(Remote_Image);

      Run_Command ("podman", Args, Dry_Run, Verbose);

      for I in Args'Range loop
         Free (Args (I));
      end loop;
      Free (Args);

      --  Push: podman push <remote>
      Args := new Argument_List (1 .. 2);
      Args (1) := new String'("push");
      Args (2) := new String'(Remote_Image);

      Run_Command ("podman", Args, Dry_Run, Verbose);

      for I in Args'Range loop
         Free (Args (I));
      end loop;
      Free (Args);

      if not Dry_Run then
         Put_Line ("Image pushed: " & Remote_Image);
      end if;
   end Push_Container;

   procedure Deploy
     (Config  : Mustfile_Config;
      Target  : String;
      Tag     : String;
      Push    : Boolean;
      Dry_Run : Boolean;
      Verbose : Boolean)
   is
      Project_Name : constant String := Must_Types.To_String (Config.Project.Name);
      Actual_Target : Deploy_Target_Type := Target_Container;
   begin
      --  Parse target
      if Target'Length > 0 then
         if Target = "local" then
            Actual_Target := Target_Local;
         elsif Target = "container" then
            Actual_Target := Target_Container;
         else
            raise Deploy_Error with "Unknown target: " & Target &
              " (use 'container' or 'local')";
         end if;
      end if;

      case Actual_Target is
         when Target_Container =>
            if not Containerfile_Exists then
               raise Deploy_Error with
                 "Containerfile not found. Create one or use --target local";
            end if;

            Put_Line ("Deploying via container...");
            Build_Container (Project_Name, Tag, Dry_Run, Verbose);

            if Push then
               --  Use default registry from config or environment
               Push_Container
                 (Project_Name => Project_Name,
                  Tag          => Tag,
                  Registry     => "ghcr.io/hyperpolymath",
                  Dry_Run      => Dry_Run,
                  Verbose      => Verbose);
            end if;

            if not Dry_Run then
               Put_Line ("Deployment complete!");
               New_Line;
               Put_Line ("Run the container:");
               Put_Line ("  podman run --rm -it " & Project_Name & ":" &
                 (if Tag'Length > 0 then Tag else "latest"));
            end if;

         when Target_Local =>
            Put_Line ("Building locally...");
            declare
               Args : Argument_List_Access := new Argument_List (1 .. 3);
            begin
               Args (1) := new String'("-P");
               Args (2) := new String'("must.gpr");
               Args (3) := new String'("-XMODE=release");

               Run_Command ("gprbuild", Args, Dry_Run, Verbose);

               for I in Args'Range loop
                  Free (Args (I));
               end loop;
               Free (Args);
            end;

            if not Dry_Run then
               Put_Line ("Local build complete: bin/must");
            end if;
      end case;
   end Deploy;

end Deployer;
