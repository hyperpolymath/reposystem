-- task_runner.adb
-- Task runner with dependency resolution for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: MPL-2.0
-- (PMPL-1.0-or-later preferred; MPL-2.0 required for GNAT ecosystem)

pragma Ada_2022;

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Directories;
with GNAT.OS_Lib;

package body Task_Runner is

   --  Make operators visible for bounded strings
   use type Bounded_String;

   --  Check if task name is in vector (now using bounded strings)
   function Contains (Vec : String_Vector; Name : Bounded_String) return Boolean is
   begin
      for Item of Vec loop
         if Item = Name then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   function Task_Exists
     (Config    : Mustfile_Config;
      Task_Name : Bounded_String) return Boolean
   is
   begin
      for T of Config.Tasks loop
         if T.Name = Task_Name then
            return True;
         end if;
      end loop;
      return False;
   end Task_Exists;

   function Get_Task
     (Config    : Mustfile_Config;
      Task_Name : Bounded_String) return Task_Def
   is
   begin
      for T of Config.Tasks loop
         if T.Name = Task_Name then
            return T;
         end if;
      end loop;
      raise Task_Error with "Task not found: " & Must_Types.To_String (Task_Name);
   end Get_Task;

   --  Internal: depth-first search for topological sort
   procedure DFS
     (Config     : Mustfile_Config;
      Task_Name  : Bounded_String;
      Visited    : in out String_Vector;
      In_Stack   : in out String_Vector;
      Result     : in out String_Vector)
   is
      T : Task_Def;
   begin
      --  Check for circular dependency
      if Contains (In_Stack, Task_Name) then
         raise Circular_Dependency with
           "Circular dependency detected involving: " & Must_Types.To_String (Task_Name);
      end if;

      --  Already processed
      if Contains (Visited, Task_Name) then
         return;
      end if;

      --  Add to current path
      In_Stack.Append (Task_Name);

      --  Get task and process dependencies
      T := Get_Task (Config, Task_Name);
      for Dep of T.Dependencies loop
         if not Task_Exists (Config, Dep) then
            raise Task_Error with
              "Task '" & Must_Types.To_String (Task_Name) &
              "' depends on unknown task: " & Must_Types.To_String (Dep);
         end if;
         DFS (Config, Dep, Visited, In_Stack, Result);
      end loop;

      --  Remove from current path
      declare
         New_Stack : String_Vector;
      begin
         for Item of In_Stack loop
            if Item /= Task_Name then
               New_Stack.Append (Item);
            end if;
         end loop;
         In_Stack := New_Stack;
      end;

      --  Mark as visited and add to result
      Visited.Append (Task_Name);
      Result.Append (Task_Name);
   end DFS;

   function Resolve_Dependencies
     (Config    : Mustfile_Config;
      Task_Name : Bounded_String) return String_Vector
   is
      Visited  : String_Vector;
      In_Stack : String_Vector;
      Result   : String_Vector;
   begin
      if not Task_Exists (Config, Task_Name) then
         raise Task_Error with "Task not found: " & Must_Types.To_String (Task_Name);
      end if;

      DFS (Config, Task_Name, Visited, In_Stack, Result);
      return Result;
   end Resolve_Dependencies;

   --  Execute a shell command (using bounded command for safety)
   function Execute_Command
     (Command : Bounded_Command;
      Verbose : Boolean) return Integer
   is
      pragma Unreferenced (Verbose);  -- Reserved for future verbose output
      use GNAT.OS_Lib;
      Args       : Argument_List_Access;
      Success    : Boolean;
      Cmd_String : constant String := Must_Types.To_Command_String (Command);
   begin
      --  Use shell to execute command
      Args := new Argument_List (1 .. 2);
      Args (1) := new String'("-c");
      Args (2) := new String'(Cmd_String);

      Spawn
        (Program_Name => "/bin/sh",
         Args         => Args.all,
         Success      => Success);

      --  Free arguments
      for I in Args'Range loop
         Free (Args (I));
      end loop;
      Free (Args);

      if Success then
         return 0;
      else
         return 1;
      end if;
   end Execute_Command;

   --  Execute a single task (without dependencies)
   procedure Execute_Task
     (Config  : Mustfile_Config;
      T       : Task_Def;
      Dry_Run : Boolean;
      Verbose : Boolean)
   is
      pragma Unreferenced (Config);  -- Reserved for future config-based execution
      Original_Dir : constant String := Ada.Directories.Current_Directory;
   begin
      --  Change to working directory if specified
      if Bounded_Paths.Length (T.Working_Dir) > 0 then
         if Verbose then
            Put_Line ("  cd " & Must_Types.To_Path_String (T.Working_Dir));
         end if;
         if not Dry_Run then
            Ada.Directories.Set_Directory (Must_Types.To_Path_String (T.Working_Dir));
         end if;
      end if;

      --  Execute commands or script
      if Bounded_Commands.Length (T.Script) > 0 then
         --  Execute script
         if Verbose or Dry_Run then
            Put_Line ("  [script]");
         end if;
         if not Dry_Run then
            declare
               Status : Integer;
            begin
               Status := Execute_Command (T.Script, Verbose);
               if Status /= 0 then
                  raise Task_Error with
                    "Script failed with exit code:" & Integer'Image (Status);
               end if;
            end;
         end if;
      else
         --  Execute commands
         for Cmd of T.Commands loop
            if Verbose or Dry_Run then
               Put_Line ("  " & Must_Types.To_Command_String (Cmd));
            end if;
            if not Dry_Run then
               declare
                  Status : Integer;
               begin
                  Status := Execute_Command (Cmd, Verbose);
                  if Status /= 0 then
                     raise Task_Error with
                       "Command failed: " & Must_Types.To_Command_String (Cmd);
                  end if;
               end;
            end if;
         end loop;
      end if;

      --  Restore original directory
      if Bounded_Paths.Length (T.Working_Dir) > 0 and then not Dry_Run then
         Ada.Directories.Set_Directory (Original_Dir);
      end if;
   end Execute_Task;

   procedure Run_Task
     (Config    : Mustfile_Config;
      Task_Name : Bounded_String;
      Dry_Run   : Boolean := False;
      Verbose   : Boolean := False)
   is
      Execution_Order : String_Vector;
   begin
      --  Get execution order (dependencies first)
      Execution_Order := Resolve_Dependencies (Config, Task_Name);

      --  Execute tasks in order
      for Name of Execution_Order loop
         declare
            T : constant Task_Def := Get_Task (Config, Name);
         begin
            if Name = Task_Name then
               Put_Line ("Running: " & Must_Types.To_String (Name));
            else
               Put_Line ("Running dependency: " & Must_Types.To_String (Name));
            end if;

            Execute_Task (Config, T, Dry_Run, Verbose);
         end;
      end loop;

      if Dry_Run then
         Put_Line ("(dry run - no commands executed)");
      else
         Put_Line ("Done.");
      end if;
   end Run_Task;

   procedure List_Tasks (Config : Mustfile_Config) is
      Max_Len : Natural := 0;
   begin
      if Config.Tasks.Is_Empty then
         Put_Line ("No tasks defined in mustfile.toml");
         return;
      end if;

      --  Find max task name length for alignment
      for T of Config.Tasks loop
         if Bounded_Strings.Length (T.Name) > Max_Len then
            Max_Len := Bounded_Strings.Length (T.Name);
         end if;
      end loop;

      Put_Line ("Available tasks:");
      Put_Line ("");

      for T of Config.Tasks loop
         declare
            Name : constant String := Must_Types.To_String (T.Name);
            Desc : constant String := Must_Types.To_Description_String (T.Description);
            Padding : constant String (1 .. Max_Len - Name'Length + 2) :=
              [others => ' '];
         begin
            if Desc'Length > 0 then
               Put_Line ("  " & Name & Padding & "# " & Desc);
            else
               Put_Line ("  " & Name);
            end if;
         end;
      end loop;
   end List_Tasks;

end Task_Runner;
