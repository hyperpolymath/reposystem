-- RSR_Adapter.adb
procedure Customize_Repo is
   type Choice is (Keep, Blank, Delete);
   Repo_Name : String := Get_Input("Project Name?");
   Author    : String := Get_Input("Your Name?");
   AI_Tool   : Choice := Get_Menu_Choice("AI Target (Claude, Copilot, None)");
begin
   -- Use SPARK to ensure file operations are memory-safe
   Update_README(Repo_Name, Author);
   if AI_Tool = None then
      Blank_File(".rhodium/ai-context.json");
   end if;
end Customize_Repo;
