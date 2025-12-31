-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
--
-- reposystem_tui.ads - Main TUI package specification (SPARK)
--
-- This package provides a terminal user interface for reposystem
-- with formal verification via SPARK.

pragma SPARK_Mode (On);

package Reposystem_TUI is

   --  Maximum dimensions
   Max_Width  : constant := 1000;
   Max_Height : constant := 500;
   Max_Repos  : constant := 10_000;
   Max_Edges  : constant := 100_000;
   Max_String : constant := 256;

   --  Screen dimensions (verified bounds)
   subtype Screen_Width is Positive range 1 .. Max_Width;
   subtype Screen_Height is Positive range 1 .. Max_Height;

   --  Repo count
   subtype Repo_Count is Natural range 0 .. Max_Repos;
   subtype Edge_Count is Natural range 0 .. Max_Edges;

   --  Bounded string for safe string handling
   subtype Bounded_String is String (1 .. Max_String);

   --  View mode enumeration
   type View_Mode is (Graph_View, List_View, Detail_View, Scenario_View);

   --  Aspect filter
   type Aspect_Filter is (All_Aspects, Security, Reliability,
                          Performance, Supply_Chain, Compliance);

   --  Application state (verified invariants)
   type App_State is record
      Width        : Screen_Width;
      Height       : Screen_Height;
      Cursor_X     : Positive;
      Cursor_Y     : Positive;
      Mode         : View_Mode;
      Filter       : Aspect_Filter;
      Repo_Count   : Repo_Count;
      Edge_Count   : Edge_Count;
      Selected     : Natural;
      Running      : Boolean;
   end record
     with Dynamic_Predicate =>
       App_State.Cursor_X <= App_State.Width and
       App_State.Cursor_Y <= App_State.Height and
       App_State.Selected <= App_State.Repo_Count;

   --  Initialize application state
   function Initialize (Width : Screen_Width; Height : Screen_Height)
     return App_State
     with Post => Initialize'Result.Running and
                  Initialize'Result.Width = Width and
                  Initialize'Result.Height = Height;

   --  Process user input
   procedure Handle_Input (State : in out App_State; Key : Character)
     with Pre  => State.Running,
          Post => State.Cursor_X <= State.Width and
                  State.Cursor_Y <= State.Height;

   --  Render current view
   procedure Render (State : App_State)
     with Pre => State.Running;

   --  Shutdown application
   procedure Shutdown (State : in out App_State)
     with Post => not State.Running;

   --  Main event loop
   procedure Run (Width : Screen_Width; Height : Screen_Height)
     with No_Return => False;

end Reposystem_TUI;
