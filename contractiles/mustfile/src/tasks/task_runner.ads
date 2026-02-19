-- task_runner.ads
-- Task runner with dependency resolution for Must
-- Copyright (C) 2025 Jonathan D.A. Jewell
-- SPDX-License-Identifier: AGPL-3.0-or-later

pragma Ada_2022;

with Must_Types; use Must_Types;

package Task_Runner is

   --  Run a task by name
   procedure Run_Task
     (Config    : Mustfile_Config;
      Task_Name : String;
      Dry_Run   : Boolean := False;
      Verbose   : Boolean := False);

   --  List all available tasks
   procedure List_Tasks (Config : Mustfile_Config);

   --  Check if a task exists
   function Task_Exists
     (Config    : Mustfile_Config;
      Task_Name : String) return Boolean;

   --  Get task definition by name
   function Get_Task
     (Config    : Mustfile_Config;
      Task_Name : String) return Task_Def;

   --  Resolve dependencies (topological sort)
   function Resolve_Dependencies
     (Config    : Mustfile_Config;
      Task_Name : String) return String_Vector;

   --  Task execution error
   Task_Error : exception;

   --  Circular dependency error
   Circular_Dependency : exception;

end Task_Runner;
