-- SPDX-License-Identifier: PMPL-1.0
-- Git_LFS implementation

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;
with GNAT.Expect; use GNAT.Expect;
with Ada.Directories;
with Progress;

package body Git_LFS is

   function Run_Git_LFS (Args : String; Dir : String := ".") return String is
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
      Full_Args : constant String := "lfs " & Args;
   begin
      begin
         Non_Blocking_Spawn
           (Pd,
            "/usr/bin/git",
            GNAT.OS_Lib.Argument_String_To_List (Full_Args).all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 60_000);
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
   end Run_Git_LFS;

   function Is_LFS_Installed return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path ("git-lfs");
      return Path /= null;
   end Is_LFS_Installed;

   function Get_LFS_Version return String is
      Result : constant String := Run_Git_LFS ("version");
   begin
      return Result;
   end Get_LFS_Version;

   function Get_LFS_Info (Repo_Path : String := ".") return LFS_Info is
      Info : LFS_Info;
      Env_Result : constant String := Run_Git_LFS ("env", Repo_Path);
      Track_Result : constant String := Run_Git_LFS ("track", Repo_Path);
   begin
      if not Is_LFS_Installed then
         Info.Status := Not_Installed;
         return Info;
      end if;

      Info.Version := To_Unbounded_String (Get_LFS_Version);

      if Index (To_Unbounded_String (Env_Result), "Endpoint") > 0 then
         Info.Status := Available;
         -- Parse endpoint from env output
         declare
            Env_Str : constant Unbounded_String := To_Unbounded_String (Env_Result);
            Start_Pos : Natural;
            End_Pos : Natural;
         begin
            Start_Pos := Index (Env_Str, "Endpoint=");
            if Start_Pos > 0 then
               Start_Pos := Start_Pos + 9;
               End_Pos := Index (Env_Str, ASCII.LF & "", Start_Pos);
               if End_Pos > Start_Pos then
                  Info.Endpoint := To_Unbounded_String
                    (Slice (Env_Str, Start_Pos, End_Pos - 1));
               end if;
            end if;
         end;
      else
         Info.Status := Not_Configured;
      end if;

      Info.Tracked_Patterns := To_Unbounded_String (Track_Result);

      return Info;
   end Get_LFS_Info;

   function Is_LFS_Enabled (Repo_Path : String := ".") return Boolean is
      Gitattributes : constant String := Repo_Path & "/.gitattributes";
   begin
      if not Ada.Directories.Exists (Gitattributes) then
         return False;
      end if;

      -- Check if .gitattributes contains LFS filter
      declare
         Content : constant String := Run_Git_LFS ("track", Repo_Path);
      begin
         return Index (To_Unbounded_String (Content), "filter=lfs") > 0 or
                Index (To_Unbounded_String (Content), "Listing tracked patterns") > 0;
      end;
   end Is_LFS_Enabled;

   procedure Install_LFS is
      Ret : Integer;
   begin
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/git",
         Args => GNAT.OS_Lib.Argument_String_To_List ("lfs install").all);
   end Install_LFS;

   procedure Track (Pattern : String; Repo_Path : String := ".") is
      Result : constant String := Run_Git_LFS ("track """ & Pattern & """", Repo_Path);
   begin
      null;
   end Track;

   procedure Untrack (Pattern : String; Repo_Path : String := ".") is
      Result : constant String := Run_Git_LFS ("untrack """ & Pattern & """", Repo_Path);
   begin
      null;
   end Untrack;

   function List_Tracked return String is
   begin
      return Run_Git_LFS ("track");
   end List_Tracked;

   procedure Fetch_LFS (Repo_Path : String := "."; Show_Progress : Boolean := True) is
      Bar : Progress.Progress_Bar;
   begin
      if Show_Progress then
         Bar := Progress.Create (100, "Fetching LFS objects");
         Progress.Display (Bar);
      end if;

      declare
         Result : constant String := Run_Git_LFS ("fetch", Repo_Path);
      begin
         if Show_Progress then
            Progress.Complete (Bar, "Fetched");
         end if;
      end;
   end Fetch_LFS;

   procedure Pull_LFS (Repo_Path : String := "."; Show_Progress : Boolean := True) is
      Bar : Progress.Progress_Bar;
   begin
      if Show_Progress then
         Bar := Progress.Create (100, "Pulling LFS objects");
         Progress.Display (Bar);
      end if;

      declare
         Result : constant String := Run_Git_LFS ("pull", Repo_Path);
      begin
         if Show_Progress then
            Progress.Complete (Bar, "Pulled");
         end if;
      end;
   end Pull_LFS;

   procedure Push_LFS (Repo_Path : String := "."; Show_Progress : Boolean := True) is
      Bar : Progress.Progress_Bar;
   begin
      if Show_Progress then
         Bar := Progress.Create (100, "Pushing LFS objects");
         Progress.Display (Bar);
      end if;

      declare
         Result : constant String := Run_Git_LFS ("push --all origin", Repo_Path);
      begin
         if Show_Progress then
            Progress.Complete (Bar, "Pushed");
         end if;
      end;
   end Push_LFS;

   procedure Migrate_Import
     (Patterns : String;
      Repo_Path : String := ".";
      Include_History : Boolean := False)
   is
      Args : constant String :=
         "migrate import --include=""" & Patterns & """" &
         (if Include_History then " --everything" else "");
      Result : constant String := Run_Git_LFS (Args, Repo_Path);
   begin
      null;
   end Migrate_Import;

   procedure Migrate_Export
     (Patterns : String;
      Repo_Path : String := ".")
   is
      Args : constant String := "migrate export --include=""" & Patterns & """";
      Result : constant String := Run_Git_LFS (Args, Repo_Path);
   begin
      null;
   end Migrate_Export;

   procedure Configure_For_Bitbucket
     (Workspace : String;
      Repo_Name : String;
      Repo_Path : String := ".")
   is
      LFS_URL : constant String :=
         "https://bitbucket.org/" & Workspace & "/" & Repo_Name & ".git/info/lfs";
      Ret : Integer;
   begin
      -- Set the LFS URL for Bitbucket
      Ret := GNAT.OS_Lib.Spawn
        (Program_Name => "/usr/bin/git",
         Args => GNAT.OS_Lib.Argument_String_To_List
           ("config lfs.url " & LFS_URL).all);
   end Configure_For_Bitbucket;

   procedure Prune (Repo_Path : String := ".") is
      Result : constant String := Run_Git_LFS ("prune", Repo_Path);
   begin
      null;
   end Prune;

   function Get_LFS_Size (Repo_Path : String := ".") return Natural is
      Result : constant String := Run_Git_LFS ("ls-files -s", Repo_Path);
      -- Would need to parse output to sum sizes
   begin
      return 0;  -- Placeholder
   end Get_LFS_Size;

   procedure Lock_File (File_Path : String) is
      Result : constant String := Run_Git_LFS ("lock " & File_Path);
   begin
      null;
   end Lock_File;

   procedure Unlock_File (File_Path : String; Force : Boolean := False) is
      Args : constant String :=
         "unlock " & File_Path & (if Force then " --force" else "");
      Result : constant String := Run_Git_LFS (Args);
   begin
      null;
   end Unlock_File;

   function List_Locks return String is
   begin
      return Run_Git_LFS ("locks");
   end List_Locks;

end Git_LFS;
