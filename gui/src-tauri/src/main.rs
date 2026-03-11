// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Reposystem GUI - Railway yard visualization for repository ecosystem

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod commands;

use std::sync::Mutex;
use reposystem::graph::EcosystemGraph;

fn main() {
    // Load graph from default location
    let config = reposystem::config::load().unwrap_or_default();
    let graph = EcosystemGraph::load(&config.data_dir).unwrap_or_else(|_| EcosystemGraph::new());

    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .manage(Mutex::new(graph))
        .invoke_handler(tauri::generate_handler![
            commands::get_repos,
            commands::get_edges,
            commands::get_groups,
            commands::get_aspects,
            commands::get_slots,
            commands::get_providers,
            commands::get_bindings,
            commands::get_plans,
            commands::add_edge,
            commands::remove_edge,
            commands::create_group,
            commands::add_to_group,
            commands::remove_from_group,
            commands::tag_aspect,
            commands::remove_aspect,
            commands::create_slot,
            commands::create_provider,
            commands::bind_slot,
            commands::unbind_slot,
            commands::save_graph,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
