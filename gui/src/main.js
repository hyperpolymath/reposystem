// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
// Main entry point - initializes TEA app and D3 graph

import { main } from './App.res.js';
import { initGraph } from './Graph.res.js';

// Initialize TEA application
const app = main();
app.run(document.getElementById('app'));

// Initialize D3 graph after DOM is ready
document.addEventListener('DOMContentLoaded', () => {
  const container = document.getElementById('graph-container');
  if (container) {
    initGraph(container);
  }
});
