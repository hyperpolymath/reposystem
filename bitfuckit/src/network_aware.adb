-- SPDX-License-Identifier: PMPL-1.0
-- Network_Aware implementation

with GNAT.OS_Lib; use type GNAT.OS_Lib.String_Access;
with GNAT.Expect; use GNAT.Expect;
with Ada.Containers.Vectors;
with Ada.Text_IO;

package body Network_Aware is

   package Op_Vectors is new Ada.Containers.Vectors
     (Index_Type => Natural, Element_Type => Scheduled_Operation);

   Pending_Operations : Op_Vectors.Vector;
   Next_Operation_ID : Natural := 1;

   function Get_Network_State return Network_State is
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
   begin
      -- Use NetworkManager's nmcli to check connectivity
      begin
         Non_Blocking_Spawn
           (Pd,
            "/usr/bin/nmcli",
            GNAT.OS_Lib.Argument_String_To_List ("networking connectivity check").all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 5_000);
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);

         -- Parse nmcli output
         declare
            Out_Str : constant String := To_String (Output);
         begin
            if Index (Output, "full") > 0 then
               return Online;
            elsif Index (Output, "limited") > 0 then
               return Partial_Connectivity;
            elsif Index (Output, "portal") > 0 then
               return Partial_Connectivity;  -- Captive portal
            elsif Index (Output, "none") > 0 then
               return Offline;
            else
               return Unknown;
            end if;
         end;

      exception
         when others =>
            return Unknown;
      end;
   end Get_Network_State;

   function Is_Metered return Boolean is
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
   begin
      -- Check active connection for metered property
      begin
         Non_Blocking_Spawn
           (Pd,
            "/usr/bin/nmcli",
            GNAT.OS_Lib.Argument_String_To_List
              ("-t -f GENERAL.METERED connection show --active").all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 3_000);
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);

         -- "yes" or "guess-yes" indicates metered
         return Index (Output, "yes") > 0;

      exception
         when others =>
            return False;  -- Assume not metered if can't determine
      end;
   end Is_Metered;

   function Is_Online return Boolean is
      State : constant Network_State := Get_Network_State;
   begin
      return State = Online or State = Metered or State = Partial_Connectivity;
   end Is_Online;

   function Get_Connection_Type return String is
      Pd : Process_Descriptor;
      Match : Expect_Match;
      Output : Unbounded_String := Null_Unbounded_String;
   begin
      begin
         Non_Blocking_Spawn
           (Pd,
            "/usr/bin/nmcli",
            GNAT.OS_Lib.Argument_String_To_List
              ("-t -f TYPE connection show --active").all,
            Err_To_Out => True);

         loop
            begin
               Expect (Pd, Match, ".+", Timeout => 3_000);
               Append (Output, Expect_Out (Pd));
            exception
               when Process_Died => exit;
            end;
         end loop;

         Close (Pd);

         declare
            Out_Str : constant String := To_String (Output);
         begin
            if Index (Output, "wifi") > 0 or Index (Output, "802-11-wireless") > 0 then
               return "wifi";
            elsif Index (Output, "ethernet") > 0 or Index (Output, "802-3-ethernet") > 0 then
               return "ethernet";
            elsif Index (Output, "gsm") > 0 or Index (Output, "cdma") > 0 then
               return "cellular";
            elsif Index (Output, "vpn") > 0 then
               return "vpn";
            else
               return "unknown";
            end if;
         end;

      exception
         when others =>
            return "unknown";
      end;
   end Get_Connection_Type;

   procedure Schedule_Operation
     (Command  : String;
      Priority : Operation_Priority := Normal)
   is
      Op : Scheduled_Operation;
   begin
      Op.ID := Next_Operation_ID;
      Next_Operation_ID := Next_Operation_ID + 1;
      Op.Command := To_Unbounded_String (Command);
      Op.Priority := Priority;
      Op.Scheduled := Clock;
      Op.Next_Retry := Clock;

      Pending_Operations.Append (Op);
   end Schedule_Operation;

   procedure Process_Pending_Operations is
      State : constant Network_State := Get_Network_State;
      Metered_Now : constant Boolean := Is_Metered;
      To_Remove : Op_Vectors.Vector;
   begin
      if State = Offline then
         return;  -- Don't process when offline
      end if;

      for Op of Pending_Operations loop
         -- Check if operation can run based on priority and network state
         declare
            Can_Run : Boolean := False;
         begin
            case Op.Priority is
               when Critical =>
                  Can_Run := State /= Offline;
               when High =>
                  Can_Run := State = Online or
                             (State = Metered and Allow_Metered_Operations);
               when Normal =>
                  Can_Run := State = Online and not Metered_Now;
               when Low =>
                  Can_Run := State = Online and not Metered_Now and
                             Get_Connection_Type = "wifi";
               when Background =>
                  Can_Run := State = Online and not Metered_Now and
                             Clock >= Op.Next_Retry;
            end case;

            if Can_Run and Clock >= Op.Next_Retry then
               -- Execute the operation
               declare
                  Ret : Integer;
               begin
                  Ret := GNAT.OS_Lib.Spawn
                    (Program_Name => "/bin/sh",
                     Args => GNAT.OS_Lib.Argument_String_To_List
                       ("-c " & To_String (Op.Command)).all);

                  if Ret = 0 then
                     To_Remove.Append (Op);  -- Success, remove from queue
                  else
                     -- Failed, schedule retry
                     declare
                        New_Op : Scheduled_Operation := Op;
                     begin
                        New_Op.Retry_Count := New_Op.Retry_Count + 1;
                        New_Op.Next_Retry := Clock + Duration (2 ** New_Op.Retry_Count);
                        New_Op.Last_Error := To_Unbounded_String
                          ("Exit code:" & Ret'Image);
                        if New_Op.Retry_Count >= New_Op.Max_Retries then
                           To_Remove.Append (Op);  -- Max retries exceeded
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;

      -- Remove completed/failed operations
      for Op of To_Remove loop
         for I in Pending_Operations.First_Index .. Pending_Operations.Last_Index loop
            if Pending_Operations (I).ID = Op.ID then
               Pending_Operations.Delete (I);
               exit;
            end if;
         end loop;
      end loop;
   end Process_Pending_Operations;

   function Pending_Operation_Count return Natural is
   begin
      return Natural (Pending_Operations.Length);
   end Pending_Operation_Count;

   procedure Clear_All_Pending is
   begin
      Pending_Operations.Clear;
   end Clear_All_Pending;

   procedure Attempt_Network_Repair is
      Ret : Integer;
   begin
      if Complete_Linux_Internet_Repair_Available then
         -- Use complete-linux-internet-repair
         Ret := GNAT.OS_Lib.Spawn
           (Program_Name => "/usr/bin/complete-linux-internet-repair",
            Args => GNAT.OS_Lib.Argument_String_To_List ("--auto").all);
      else
         -- Basic repair: restart NetworkManager
         Ret := GNAT.OS_Lib.Spawn
           (Program_Name => "/usr/bin/nmcli",
            Args => GNAT.OS_Lib.Argument_String_To_List ("networking off").all);
         delay 2.0;
         Ret := GNAT.OS_Lib.Spawn
           (Program_Name => "/usr/bin/nmcli",
            Args => GNAT.OS_Lib.Argument_String_To_List ("networking on").all);
      end if;
   end Attempt_Network_Repair;

   function Complete_Linux_Internet_Repair_Available return Boolean is
      Path : GNAT.OS_Lib.String_Access;
   begin
      Path := GNAT.OS_Lib.Locate_Exec_On_Path ("complete-linux-internet-repair");
      return Path /= null;
   end Complete_Linux_Internet_Repair_Available;

   procedure Set_Allow_On_Metered (Enabled : Boolean) is
   begin
      Allow_Metered_Operations := Enabled;
   end Set_Allow_On_Metered;

   procedure Set_Max_Background_Bandwidth_KBps (Limit : Natural) is
   begin
      Max_Background_BW_KBps := Limit;
   end Set_Max_Background_Bandwidth_KBps;

   function Get_Allow_On_Metered return Boolean is
   begin
      return Allow_Metered_Operations;
   end Get_Allow_On_Metered;

end Network_Aware;
