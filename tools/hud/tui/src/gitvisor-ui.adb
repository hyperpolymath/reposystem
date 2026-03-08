-- SPDX-License-Identifier: MIT OR AGPL-3.0-or-later WITH Palimpsest-0.8

with Ada.Text_IO;
with Ada.Characters.Latin_1;

package body Gitvisor.UI is

   use Ada.Text_IO;

   --  ANSI escape sequences
   ESC : constant Character := Ada.Characters.Latin_1.ESC;

   procedure Clear_Screen is
   begin
      Put (ESC & "[2J" & ESC & "[H");
   end Clear_Screen;

   procedure Move_Cursor (Row, Col : Positive) is
      Row_Img : constant String := Positive'Image (Row);
      Col_Img : constant String := Positive'Image (Col);
   begin
      Put (ESC & "[" & Row_Img (2 .. Row_Img'Last) & ";" &
           Col_Img (2 .. Col_Img'Last) & "H");
   end Move_Cursor;

   procedure Set_Color (FG : Natural; Bold : Boolean := False) is
      FG_Img : constant String := Natural'Image (FG);
   begin
      if Bold then
         Put (ESC & "[1;" & FG_Img (2 .. FG_Img'Last) & "m");
      else
         Put (ESC & "[" & FG_Img (2 .. FG_Img'Last) & "m");
      end if;
   end Set_Color;

   procedure Reset_Color is
   begin
      Put (ESC & "[0m");
   end Reset_Color;

   procedure Draw_Header (App : Application) is
   begin
      Set_Color (36, True);  --  Cyan, bold
      Put_Line ("╔════════════════════════════════════════════════════════════════╗");
      Put ("║");
      Set_Color (37, True);  --  White, bold
      Put ("  GITVISOR");
      Set_Color (36);
      Put ("  │  ");

      --  Show current platform
      case App.Platform is
         when GitHub =>
            Set_Color (32);  --  Green
            Put ("GitHub");
         when GitLab =>
            Set_Color (33);  --  Yellow/Orange
            Put ("GitLab");
         when others =>
            Put (Platform_Type'Image (App.Platform));
      end case;

      Set_Color (36);
      Put_Line ("                                          ║");
      Put_Line ("╠════════════════════════════════════════════════════════════════╣");
      Reset_Color;
   end Draw_Header;

   procedure Draw_Tabs (App : Application) is
      type Tab_Info is record
         Name : String (1 .. 12);
         View : View_Mode;
      end record;

      Tabs : constant array (1 .. 5) of Tab_Info :=
        ((Name => "Dashboard   ", View => Dashboard),
         (Name => "Repos       ", View => Repositories),
         (Name => "Issues      ", View => Issues),
         (Name => "PRs         ", View => Pull_Requests),
         (Name => "Settings    ", View => Settings));
   begin
      Put ("║ ");
      for I in Tabs'Range loop
         if Tabs (I).View = App.View then
            Set_Color (30, True);  --  Black on...
            Put (ESC & "[47m");    --  White background
         else
            Set_Color (37);
         end if;
         Put (" " & Tabs (I).Name & " ");
         Reset_Color;
         Set_Color (36);
         if I < Tabs'Last then
            Put ("│");
         end if;
      end loop;
      Put_Line ("      ║");
      Put_Line ("╠════════════════════════════════════════════════════════════════╣");
      Reset_Color;
   end Draw_Tabs;

   procedure Draw_Content (App : Application) is
   begin
      Set_Color (36);
      case App.View is
         when Dashboard =>
            Put_Line ("║  Welcome to Gitvisor                                            ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Connected platforms: " &
                     (if App.Platform = GitHub then "GitHub " else "GitLab ") &
                     "                                ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Quick stats:                                                   ║");
            Put_Line ("║    Repositories: --                                             ║");
            Put_Line ("║    Open Issues: --                                              ║");
            Put_Line ("║    Open PRs: --                                                 ║");

         when Repositories =>
            Put_Line ("║  Repositories                                                   ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Loading...                                                     ║");

         when Issues =>
            Put_Line ("║  Issues                                                         ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Loading...                                                     ║");

         when Pull_Requests =>
            Put_Line ("║  Pull Requests                                                  ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Loading...                                                     ║");

         when Settings =>
            Put_Line ("║  Settings                                                       ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Platform: " &
                     Platform_Type'Image (App.Platform) &
                     "                                            ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  [P] Switch platform                                            ║");
            Put_Line ("║  [T] Configure tokens                                           ║");

         when Help =>
            Put_Line ("║  Help                                                           ║");
            Put_Line ("║                                                                  ║");
            Put_Line ("║  Navigation:                                                    ║");
            Put_Line ("║    ↑/k - Up      ↓/j - Down                                    ║");
            Put_Line ("║    ←/h - Left    →/l - Right                                   ║");
            Put_Line ("║    Enter - Select   Esc/q - Back/Quit                          ║");
            Put_Line ("║    / - Search   r - Refresh   ? - Help                         ║");
      end case;
      Reset_Color;
   end Draw_Content;

   procedure Draw_Footer is
   begin
      Set_Color (36);
      Put_Line ("╠════════════════════════════════════════════════════════════════╣");
      Put_Line ("║ [q]uit [?]help [/]search [r]efresh [Tab]switch              ║");
      Put_Line ("╚════════════════════════════════════════════════════════════════╝");
      Reset_Color;
   end Draw_Footer;

   procedure Render (App : Application) is
   begin
      Clear_Screen;
      Draw_Header (App);
      Draw_Tabs (App);
      Draw_Content (App);
      Draw_Footer;
   end Render;

   procedure Initialize
     (App    : out Application;
      Config : in  Gitvisor.Config.Settings)
   is
      pragma Unreferenced (Config);
   begin
      App := (View          => Dashboard,
              Running       => True,
              Selected_Row  => 0,
              Scroll_Offset => 0,
              Search_Query  => (others => ' '),
              Search_Length => 0,
              Platform      => GitHub);
   end Initialize;

   function Get_Action return Action is
      C : Character;
      Available : Boolean;
   begin
      Ada.Text_IO.Get_Immediate (C, Available);
      if not Available then
         return None;
      end if;

      case C is
         when 'q' | 'Q' =>
            return Quit;
         when 'k' | 'K' =>
            return Navigate_Up;
         when 'j' | 'J' =>
            return Navigate_Down;
         when 'h' | 'H' =>
            return Navigate_Left;
         when 'l' | 'L' =>
            return Navigate_Right;
         when ASCII.CR | ASCII.LF =>
            return Select_Item;
         when ASCII.ESC =>
            return Back;
         when 'r' | 'R' =>
            return Refresh;
         when '/' =>
            return Search;
         when 'p' | 'P' =>
            return Switch_Platform;
         when '?' =>
            return Show_Help;
         when others =>
            return None;
      end case;
   end Get_Action;

   procedure Update (App : in out Application; Act : Action) is
   begin
      case Act is
         when Quit =>
            App.Running := False;

         when Navigate_Left =>
            if App.View > View_Mode'First then
               App.View := View_Mode'Pred (App.View);
            end if;

         when Navigate_Right =>
            if App.View < Settings then
               App.View := View_Mode'Succ (App.View);
            end if;

         when Navigate_Up =>
            if App.Selected_Row > 0 then
               App.Selected_Row := App.Selected_Row - 1;
            end if;

         when Navigate_Down =>
            App.Selected_Row := App.Selected_Row + 1;

         when Switch_Platform =>
            if App.Platform = GitHub then
               App.Platform := GitLab;
            else
               App.Platform := GitHub;
            end if;

         when Show_Help =>
            App.View := Help;

         when Back =>
            if App.View = Help then
               App.View := Dashboard;
            else
               App.Running := False;
            end if;

         when others =>
            null;
      end case;
   end Update;

   procedure Run (App : in out Application) is
      Act : Action;
   begin
      while App.Running loop
         Render (App);
         Act := Get_Action;
         Update (App, Act);
         delay 0.05;  --  50ms refresh
      end loop;
   end Run;

   procedure Finalize (App : in out Application) is
   begin
      Clear_Screen;
      Reset_Color;
      App.Running := False;
   end Finalize;

   function Current_View (App : Application) return View_Mode is
   begin
      return App.View;
   end Current_View;

end Gitvisor.UI;
