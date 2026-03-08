-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

--  Gitvisor.UI - Terminal User Interface
--
--  Manages the terminal display and user interaction.
--  Uses a Model-View-Update architecture similar to TEA.

with Gitvisor.Config;

package Gitvisor.UI is

   --  Application state
   type Application is private;

   --  View modes
   type View_Mode is
     (Dashboard,
      Repositories,
      Issues,
      Pull_Requests,
      Settings,
      Help);

   --  User actions
   type Action is
     (None,
      Quit,
      Navigate_Up,
      Navigate_Down,
      Navigate_Left,
      Navigate_Right,
      Select_Item,
      Back,
      Refresh,
      Search,
      Switch_Platform,
      Show_Help);

   --  Initialize the application
   procedure Initialize
     (App    : out Application;
      Config : in  Gitvisor.Config.Settings);

   --  Main event loop
   procedure Run (App : in out Application);

   --  Clean up resources
   procedure Finalize (App : in out Application);

   --  Get current view mode
   function Current_View (App : Application) return View_Mode;

   --  Process user input and return action
   function Get_Action return Action;

private

   type Application is record
      View         : View_Mode := Dashboard;
      Running      : Boolean := False;
      Selected_Row : Natural := 0;
      Scroll_Offset : Natural := 0;
      Search_Query : String (1 .. 256) := (others => ' ');
      Search_Length : Natural := 0;
      Platform     : Platform_Type := GitHub;
   end record;

end Gitvisor.UI;
