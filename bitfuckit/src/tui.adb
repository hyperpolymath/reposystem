-- SPDX-License-Identifier: PMPL-1.0

with Ada.Text_IO; use Ada.Text_IO;
with Ada.Characters.Latin_1;

package body TUI
   with SPARK_Mode => Off  -- I/O operations
is
   package Latin renames Ada.Characters.Latin_1;

   ESC : constant Character := Latin.ESC;

   function Color_Code (C : Color) return String is
   begin
      case C is
         when Default => return "0";
         when Red     => return "31";
         when Green   => return "32";
         when Yellow  => return "33";
         when Blue    => return "34";
         when Magenta => return "35";
         when Cyan    => return "36";
         when White   => return "37";
      end case;
   end Color_Code;

   procedure Clear_Screen is
   begin
      Put (ESC & "[2J" & ESC & "[H");
   end Clear_Screen;

   procedure Move_Cursor (Row, Col : Positive) is
      Row_Str : constant String := Positive'Image (Row);
      Col_Str : constant String := Positive'Image (Col);
   begin
      Put (ESC & "[" & Row_Str (2 .. Row_Str'Last) & ";" &
           Col_Str (2 .. Col_Str'Last) & "H");
   end Move_Cursor;

   procedure Set_Color (Fg : Color; Bold : Boolean := False) is
      Bold_Str : constant String := (if Bold then "1;" else "");
   begin
      Put (ESC & "[" & Bold_Str & Color_Code (Fg) & "m");
   end Set_Color;

   procedure Reset_Color is
   begin
      Put (ESC & "[0m");
   end Reset_Color;

   procedure Put_Colored (Text : String; Fg : Color; Bold : Boolean := False) is
   begin
      Set_Color (Fg, Bold);
      Put (Text);
      Reset_Color;
   end Put_Colored;

   procedure Put_Line_Colored (Text : String; Fg : Color; Bold : Boolean := False) is
   begin
      Set_Color (Fg, Bold);
      Put_Line (Text);
      Reset_Color;
   end Put_Line_Colored;

   -- Box drawing using ASCII for Latin-1 compatibility
   Box_H  : constant String := "=";  -- Horizontal line
   Box_V  : constant String := "|";  -- Vertical line
   Box_TL : constant String := "+";  -- Top-left corner
   Box_TR : constant String := "+";  -- Top-right corner
   Box_BL : constant String := "+";  -- Bottom-left corner
   Box_BR : constant String := "+";  -- Bottom-right corner

   function Repeat_Char (S : String; N : Natural) return String is
      Result : String (1 .. N * S'Length);
   begin
      for I in 0 .. N - 1 loop
         Result (I * S'Length + 1 .. (I + 1) * S'Length) := S;
      end loop;
      return Result;
   end Repeat_Char;

   procedure Draw_Header (Title : String) is
      Line : constant String := Repeat_Char (Box_H, 60);
   begin
      Move_Cursor (1, 1);
      Put_Colored (Box_TL & Line & Box_TR, Cyan, True);
      Move_Cursor (2, 1);
      Put_Colored (Box_V, Cyan, True);
      Set_Color (Yellow, True);
      Put ("  [*] " & Title);
      Move_Cursor (2, 62);
      Put_Colored (Box_V, Cyan, True);
      Move_Cursor (3, 1);
      Put_Colored (Box_BL & Line & Box_BR, Cyan, True);
   end Draw_Header;

   procedure Draw_Footer (Status : String) is
   begin
      Move_Cursor (24, 1);
      Put_Colored (Repeat_Char ("-", 61), Blue);
      Move_Cursor (25, 1);
      Put_Colored (Status, White);
   end Draw_Footer;

   procedure Draw_Box (Row, Col, Width, Height : Positive; Title : String := "") is
      Top_Line    : constant String := Repeat_Char ("-", Width - 2);
      Bottom_Line : constant String := Repeat_Char ("-", Width - 2);
      Empty_Line  : constant String (1 .. Width - 2) := (others => ' ');
   begin
      Move_Cursor (Row, Col);
      Put ("+" & Top_Line & "+");

      if Title'Length > 0 then
         Move_Cursor (Row, Col + 2);
         Put_Colored (" " & Title & " ", Yellow, True);
      end if;

      for I in 1 .. Height - 2 loop
         Move_Cursor (Row + I, Col);
         Put ("|" & Empty_Line & "|");
      end loop;

      Move_Cursor (Row + Height - 1, Col);
      Put ("+" & Bottom_Line & "+");
   end Draw_Box;

   procedure Draw_Menu (Items : Menu_Items; Selected : Positive) is
   begin
      for I in Items'Range loop
         Move_Cursor (5 + I, 4);
         if I = Selected then
            Put_Colored ("> ", Green, True);
            Put_Colored ("[" & Items (I).Key & "] ", Yellow, True);
            Put_Colored (To_String (Items (I).Label), White, True);
         else
            Put ("  ");
            Put_Colored ("[" & Items (I).Key & "] ", Cyan);
            Put (To_String (Items (I).Label));
         end if;
         Put (" - ");
         Put_Colored (To_String (Items (I).Description), Blue);
      end loop;
   end Draw_Menu;

   procedure Draw_Progress (Current, Total : Natural; Label : String) is
      Width    : constant := 40;
      Filled   : Natural;
      Bar      : String (1 .. Width);
   begin
      if Total > 0 then
         Filled := (Current * Width) / Total;
      else
         Filled := 0;
      end if;

      for I in 1 .. Width loop
         if I <= Filled then
            Bar (I) := '#';
         else
            Bar (I) := '.';
         end if;
      end loop;

      Move_Cursor (20, 4);
      Put_Colored (Label & ": ", White);
      Put_Colored ("[", Cyan);
      Put_Colored (Bar (1 .. Filled), Green);
      Put (Bar (Filled + 1 .. Width));
      Put_Colored ("]", Cyan);
      Put_Colored (Natural'Image (Current) & "/" & Natural'Image (Total), Yellow);
   end Draw_Progress;

   function Get_Key return Character is
      C : Character;
   begin
      Get_Immediate (C);
      return C;
   end Get_Key;

   function Get_Line_Input (Prompt : String) return Unbounded_String is
      Line : String (1 .. 256);
      Last : Natural;
   begin
      Put_Colored (Prompt, Cyan);
      Put (": ");
      Get_Line (Line, Last);
      return To_Unbounded_String (Line (1 .. Last));
   end Get_Line_Input;

   function Confirm (Prompt : String) return Boolean is
      C : Character;
   begin
      Put_Colored (Prompt & " [y/N]: ", Yellow);
      Get_Immediate (C);
      New_Line;
      return C = 'y' or C = 'Y';
   end Confirm;

   procedure Show_Troubleshooter is
      Trouble_Menu : constant Menu_Items := (
         1 => (Key => '1', Label => To_Unbounded_String ("Auth Issues"),
               Description => To_Unbounded_String ("Login and credential problems")),
         2 => (Key => '2', Label => To_Unbounded_String ("Network"),
               Description => To_Unbounded_String ("Connection and API issues")),
         3 => (Key => '3', Label => To_Unbounded_String ("Git LFS"),
               Description => To_Unbounded_String ("Large file storage problems")),
         4 => (Key => '4', Label => To_Unbounded_String ("SSH Keys"),
               Description => To_Unbounded_String ("SSH authentication issues")),
         5 => (Key => '5', Label => To_Unbounded_String ("Rate Limits"),
               Description => To_Unbounded_String ("API throttling and limits")),
         6 => (Key => 'b', Label => To_Unbounded_String ("Back"),
               Description => To_Unbounded_String ("Return to main menu"))
      );
      Selected : Positive := 1;
      Key : Character;
      Running : Boolean := True;
   begin
      while Running loop
         Clear_Screen;
         Draw_Header ("TROUBLESHOOTER");
         Draw_Box (4, 2, 58, 14, "Select Issue Type");
         Draw_Menu (Trouble_Menu, Selected);

         Move_Cursor (18, 4);
         Put_Colored ("Tip: ", Yellow, True);
         Put ("Press ? to open docs in browser");

         Draw_Footer ("j/k Navigate | Enter Select | b Back | ? Help");

         Key := Get_Key;

         case Key is
            when 'k' | 'A' =>
               if Selected > 1 then
                  Selected := Selected - 1;
               end if;
            when 'j' | 'B' =>
               if Selected < Trouble_Menu'Length then
                  Selected := Selected + 1;
               end if;
            when Latin.LF | Latin.CR =>
               case Selected is
                  when 1 =>  -- Auth Issues
                     Clear_Screen;
                     Draw_Header ("AUTH TROUBLESHOOTING");
                     Move_Cursor (5, 4);
                     Put_Line_Colored ("Authentication Issues", Yellow, True);
                     Move_Cursor (7, 4);
                     Put_Line ("Problem: 'Not logged in' or '401 Unauthorized'");
                     Move_Cursor (9, 4);
                     Put_Line_Colored ("Solutions:", Green, True);
                     Move_Cursor (10, 4);
                     Put_Line ("1. Run: bitfuckit auth login");
                     Move_Cursor (11, 4);
                     Put_Line ("2. Create an app password with these scopes:");
                     Move_Cursor (12, 7);
                     Put_Line ("- repository:read, repository:write");
                     Move_Cursor (13, 7);
                     Put_Line ("- pullrequest:read, pullrequest:write");
                     Move_Cursor (15, 4);
                     Put_Line_Colored ("Link:", Cyan);
                     Move_Cursor (16, 4);
                     Put_Line ("https://bitbucket.org/account/settings/app-passwords/");
                     Move_Cursor (20, 4);
                     Put_Colored ("Press any key to continue...", Blue);
                     Key := Get_Key;
                  when 2 =>  -- Network
                     Clear_Screen;
                     Draw_Header ("NETWORK TROUBLESHOOTING");
                     Move_Cursor (5, 4);
                     Put_Line_Colored ("Network Issues", Yellow, True);
                     Move_Cursor (7, 4);
                     Put_Line ("Problem: Connection refused, timeout, DNS error");
                     Move_Cursor (9, 4);
                     Put_Line_Colored ("Diagnostics:", Green, True);
                     Move_Cursor (10, 4);
                     Put_Line ("1. Run: bitfuckit network status");
                     Move_Cursor (11, 4);
                     Put_Line ("2. Run: bitfuckit network check");
                     Move_Cursor (12, 4);
                     Put_Line ("3. Check: ping api.bitbucket.org");
                     Move_Cursor (14, 4);
                     Put_Line_Colored ("Common fixes:", Green, True);
                     Move_Cursor (15, 4);
                     Put_Line ("- Check proxy: $HTTPS_PROXY, $HTTP_PROXY");
                     Move_Cursor (16, 4);
                     Put_Line ("- Check firewall: sudo firewall-cmd --list-all");
                     Move_Cursor (17, 4);
                     Put_Line ("- Use offline mode: bitfuckit --offline <cmd>");
                     Move_Cursor (20, 4);
                     Put_Colored ("Press any key to continue...", Blue);
                     Key := Get_Key;
                  when 3 =>  -- Git LFS
                     Clear_Screen;
                     Draw_Header ("GIT LFS TROUBLESHOOTING");
                     Move_Cursor (5, 4);
                     Put_Line_Colored ("Git LFS Issues", Yellow, True);
                     Move_Cursor (7, 4);
                     Put_Line ("Problem: LFS not installed, files not tracked");
                     Move_Cursor (9, 4);
                     Put_Line_Colored ("Setup steps:", Green, True);
                     Move_Cursor (10, 4);
                     Put_Line ("1. Install: dnf install git-lfs");
                     Move_Cursor (11, 4);
                     Put_Line ("2. Initialize: git lfs install");
                     Move_Cursor (12, 4);
                     Put_Line ("3. Track: bitfuckit lfs track '*.psd'");
                     Move_Cursor (14, 4);
                     Put_Line_Colored ("Check status:", Green, True);
                     Move_Cursor (15, 4);
                     Put_Line ("bitfuckit lfs status");
                     Move_Cursor (17, 4);
                     Put_Line_Colored ("Docs:", Cyan);
                     Move_Cursor (18, 4);
                     Put_Line ("https://github.com/hyperpolymath/bitfuckit/wiki/Git-LFS");
                     Move_Cursor (20, 4);
                     Put_Colored ("Press any key to continue...", Blue);
                     Key := Get_Key;
                  when 4 =>  -- SSH Keys
                     Clear_Screen;
                     Draw_Header ("SSH KEY TROUBLESHOOTING");
                     Move_Cursor (5, 4);
                     Put_Line_Colored ("SSH Key Issues", Yellow, True);
                     Move_Cursor (7, 4);
                     Put_Line ("Problem: Permission denied (publickey)");
                     Move_Cursor (9, 4);
                     Put_Line_Colored ("Setup steps:", Green, True);
                     Move_Cursor (10, 4);
                     Put_Line ("1. Generate key: ssh-keygen -t ed25519");
                     Move_Cursor (11, 4);
                     Put_Line ("2. Copy pubkey: cat ~/.ssh/id_ed25519.pub");
                     Move_Cursor (12, 4);
                     Put_Line ("3. Add to Bitbucket account settings");
                     Move_Cursor (14, 4);
                     Put_Line_Colored ("Test connection:", Green, True);
                     Move_Cursor (15, 4);
                     Put_Line ("ssh -T git@bitbucket.org");
                     Move_Cursor (17, 4);
                     Put_Line_Colored ("Link:", Cyan);
                     Move_Cursor (18, 4);
                     Put_Line ("https://bitbucket.org/account/settings/ssh-keys/");
                     Move_Cursor (20, 4);
                     Put_Colored ("Press any key to continue...", Blue);
                     Key := Get_Key;
                  when 5 =>  -- Rate Limits
                     Clear_Screen;
                     Draw_Header ("RATE LIMIT TROUBLESHOOTING");
                     Move_Cursor (5, 4);
                     Put_Line_Colored ("Rate Limiting", Yellow, True);
                     Move_Cursor (7, 4);
                     Put_Line ("Problem: 429 Too Many Requests");
                     Move_Cursor (9, 4);
                     Put_Line_Colored ("How bitfuckit handles this:", Green, True);
                     Move_Cursor (10, 4);
                     Put_Line ("- Circuit breaker opens after 5 failures");
                     Move_Cursor (11, 4);
                     Put_Line ("- Auto-resets after 30 seconds");
                     Move_Cursor (12, 4);
                     Put_Line ("- Retries with exponential backoff + jitter");
                     Move_Cursor (14, 4);
                     Put_Line_Colored ("Best practices:", Green, True);
                     Move_Cursor (15, 4);
                     Put_Line ("- Use --offline for cached operations");
                     Move_Cursor (16, 4);
                     Put_Line ("- Batch operations when possible");
                     Move_Cursor (17, 4);
                     Put_Line ("- Wait and retry if circuit breaker opens");
                     Move_Cursor (20, 4);
                     Put_Colored ("Press any key to continue...", Blue);
                     Key := Get_Key;
                  when 6 =>  -- Back
                     Running := False;
                  when others => null;
               end case;
            when '?' =>
               Move_Cursor (20, 4);
               Put_Colored ("Wiki: github.com/hyperpolymath/bitfuckit/wiki", Cyan);
               Move_Cursor (21, 4);
               Put ("Opening in browser would happen here...");
               delay 1.5;
            when 'b' | 'q' | Latin.ESC =>
               Running := False;
            when others =>
               null;
         end case;
      end loop;
   end Show_Troubleshooter;

   procedure Show_Help (Topic : String := "") is
   begin
      Clear_Screen;
      Draw_Header ("HELP");
      Move_Cursor (5, 4);
      Put_Line_Colored ("bitfuckit - The Bitbucket CLI Atlassian never made", Yellow, True);
      Move_Cursor (7, 4);
      Put_Line ("TUI Controls:");
      Move_Cursor (8, 6);
      Put_Line ("j / Down   - Move down");
      Move_Cursor (9, 6);
      Put_Line ("k / Up     - Move up");
      Move_Cursor (10, 6);
      Put_Line ("Enter      - Select item");
      Move_Cursor (11, 6);
      Put_Line ("t          - Open troubleshooter");
      Move_Cursor (12, 6);
      Put_Line ("h / ?      - Show help");
      Move_Cursor (13, 6);
      Put_Line ("q / Esc    - Quit / Back");
      Move_Cursor (15, 4);
      Put_Line_Colored ("Documentation:", Cyan, True);
      Move_Cursor (16, 6);
      Put_Line ("man bitfuckit");
      Move_Cursor (17, 6);
      Put_Line ("https://github.com/hyperpolymath/bitfuckit/wiki");
      Move_Cursor (19, 4);
      Put_Colored ("Press any key to continue...", Blue);
      declare
         Dummy : Character := Get_Key;
      begin
         null;
      end;
   end Show_Help;

   procedure Run_TUI is
      Main_Menu : constant Menu_Items := (
         1 => (Key => 'l', Label => To_Unbounded_String ("Login"),
               Description => To_Unbounded_String ("Authenticate with Bitbucket")),
         2 => (Key => 's', Label => To_Unbounded_String ("Status"),
               Description => To_Unbounded_String ("Show auth status")),
         3 => (Key => 'c', Label => To_Unbounded_String ("Create"),
               Description => To_Unbounded_String ("Create a new repository")),
         4 => (Key => 'r', Label => To_Unbounded_String ("Repos"),
               Description => To_Unbounded_String ("List all repositories")),
         5 => (Key => 'm', Label => To_Unbounded_String ("Mirror"),
               Description => To_Unbounded_String ("Mirror from GitHub")),
         6 => (Key => 'd', Label => To_Unbounded_String ("Delete"),
               Description => To_Unbounded_String ("Delete a repository")),
         7 => (Key => 't', Label => To_Unbounded_String ("Troubleshoot"),
               Description => To_Unbounded_String ("Diagnose common issues")),
         8 => (Key => 'q', Label => To_Unbounded_String ("Quit"),
               Description => To_Unbounded_String ("Exit bitfuckit"))
      );
      Selected : Positive := 1;
      Key : Character;
      Running : Boolean := True;
   begin
      while Running loop
         Clear_Screen;
         Draw_Header ("BITFUCKIT - Bitbucket CLI");
         Draw_Box (4, 2, 58, 14, "Main Menu");
         Draw_Menu (Main_Menu, Selected);
         Draw_Footer ("j/k Navigate | Enter Select | h Help | q Quit");

         Key := Get_Key;

         case Key is
            when 'k' | 'A' =>  -- Up arrow (A is part of escape sequence)
               if Selected > 1 then
                  Selected := Selected - 1;
               end if;
            when 'j' | 'B' =>  -- Down arrow
               if Selected < Main_Menu'Length then
                  Selected := Selected + 1;
               end if;
            when Latin.LF | Latin.CR =>  -- Enter
               case Selected is
                  when 1 => null; -- Login (TODO: implement)
                  when 2 => null; -- Status (TODO: implement)
                  when 3 => null; -- Create (TODO: implement)
                  when 4 => null; -- List (TODO: implement)
                  when 5 => null; -- Mirror (TODO: implement)
                  when 6 => null; -- Delete (TODO: implement)
                  when 7 => Show_Troubleshooter;
                  when 8 => Running := False;
                  when others => null;
               end case;
            when 'l' => null; -- Login shortcut
            when 's' => null; -- Status shortcut
            when 'c' => null; -- Create shortcut
            when 'r' => null; -- Repos shortcut
            when 'm' => null; -- Mirror shortcut
            when 'd' => null; -- Delete shortcut
            when 't' => Show_Troubleshooter;
            when 'h' | '?' => Show_Help;
            when 'q' | Latin.ESC =>
               Running := False;
            when others =>
               null;
         end case;
      end loop;

      Clear_Screen;
      Put_Line_Colored ("Goodbye!", Cyan, True);
   end Run_TUI;

end TUI;
