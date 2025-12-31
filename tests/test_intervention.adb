-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
--
-- test_intervention.adb - Tests for vex-SATELLITE_NAME intervention

with Ada.Text_IO;
with Intervention;

procedure Test_Intervention is
   use Ada.Text_IO;

   --  Test cases - replace with actual examples
   Test_Input_Clean    : constant String := "This is clean content";
   Test_Input_Problem  : constant String := "TODO: implement this";

   Result : Intervention.Intervention_Result;
begin
   Put_Line ("=== vex-SATELLITE_NAME Test Suite ===");
   New_Line;

   --  Test 1: Clean content should not trigger intervention
   Put_Line ("Test 1: Clean content detection");
   if not Intervention.Analyse (Test_Input_Clean) then
      Put_Line ("  PASS: Clean content correctly identified");
   else
      Put_Line ("  FAIL: False positive on clean content");
   end if;
   New_Line;

   --  Test 2: Problematic content should be detected
   Put_Line ("Test 2: Problem detection");
   if Intervention.Analyse (Test_Input_Problem) then
      Put_Line ("  PASS: Problem correctly detected");
   else
      Put_Line ("  FAIL: Problem not detected");
   end if;
   New_Line;

   --  Test 3: Intervention should produce result
   Put_Line ("Test 3: Intervention execution");
   Result := Intervention.Intervene (Test_Input_Problem);
   if Result.Success then
      Put_Line ("  PASS: Intervention successful");
      Put_Line ("  Reduction: " & Float'Image (Result.Reduction));
   else
      Put_Line ("  Result: " & Result.Message (1 .. Result.Message_Last));
   end if;

   New_Line;
   Put_Line ("=== Tests Complete ===");
end Test_Intervention;
