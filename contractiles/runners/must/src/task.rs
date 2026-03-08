// src/task.rs
use std::process::Command;

pub fn run_task(task_name: &str, mustfile: &MustFile) -> Result<(), String> {
    let task = mustfile.tasks.get(task_name)
        .ok_or_else(|| format!("❌ Task {} not found", task_name))?;

    // Pre-task validation
    validate_state(mustfile)?;

    // Execute steps
    for step in &task.steps {
        println!("🛠️ Running: {}", step);
        let status = Command::new("sh").arg("-c").arg(step).status().map_err(|e| e.to_string())?;
        if !status.success() {
            return Err(format!("❌ Step failed: {}", step));
        }
    }

    // Post-task validation
    validate_state(mustfile)?;
    Ok(())
}
