-- SPDX-License-Identifier: AGPL-3.0-or-later
-- SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
--
-- intervention.ads - Main intervention interface for vex-SATELLITE_NAME
--
-- Replace SATELLITE_NAME, METRIC_NAME, DESCRIPTION throughout.

package Intervention is

   --  Intervention target: METRIC_NAME
   --
   --  DESCRIPTION

   type Intervention_Result is record
      Success      : Boolean;
      Message      : String (1 .. 256);
      Message_Last : Natural;
      --  Metric reduction achieved (0.0 = no improvement, 1.0 = fully resolved)
      Reduction    : Float range 0.0 .. 1.0;
   end record;

   --  Analyse content for issues this intervention addresses
   function Analyse (Content : String) return Boolean;

   --  Apply intervention to content
   function Apply (Content : String) return String
     with Pre => Analyse (Content);

   --  Full intervention with result tracking
   function Intervene (Content : String) return Intervention_Result;

   --  Vexometer integration: generate trace data
   procedure Generate_Trace
     (Content  : String;
      Filename : String);

end Intervention;
