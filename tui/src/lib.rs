// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Reposystem TUI — core types and logic.
//!
//! Migrated from Ada/SPARK (`legacy-ada/`). All SPARK contracts are preserved:
//!
//! - **Dynamic_Predicate** → validated constructors + `debug_assert!` on mutation
//! - **Pre/Post conditions** → `debug_assert!` at function boundaries
//! - **SPARK subtypes** → Rust newtypes with bounded ranges
//! - **Ghost state** → `#[cfg(test)]` property checks
//!
//! # Safety Contract Summary
//!
//! The `AppState` invariant (from Ada Dynamic_Predicate) is:
//!   - `cursor_x` in `1..=width`
//!   - `cursor_y` in `1..=height`
//!   - `selected` in `0..=repo_count`
//!   - `width` in `1..=MAX_WIDTH`
//!   - `height` in `1..=MAX_HEIGHT`

#![forbid(unsafe_code)]

use std::fmt;

// =============================================================================
// Constants — mirrors Ada `Max_*` constants
// =============================================================================

/// Maximum terminal width (mirrors Ada `Max_Width : constant := 1000`).
pub const MAX_WIDTH: u16 = 1000;

/// Maximum terminal height (mirrors Ada `Max_Height : constant := 500`).
pub const MAX_HEIGHT: u16 = 500;

/// Maximum number of repositories in the graph
/// (mirrors Ada `Max_Repos : constant := 10_000`).
pub const MAX_REPOS: u32 = 10_000;

/// Maximum number of edges in the graph
/// (mirrors Ada `Max_Edges : constant := 100_000`).
pub const MAX_EDGES: u32 = 100_000;

/// Maximum bounded string length
/// (mirrors Ada `Max_String : constant := 256`).
pub const MAX_STRING: usize = 256;

// =============================================================================
// Enums — mirrors Ada enumeration types
// =============================================================================

/// View mode for the TUI display.
///
/// Mirrors Ada `type View_Mode is (Graph_View, List_View, Detail_View,
///   Scenario_View, PanLL_View)`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum ViewMode {
    /// Dependency graph visualization.
    Graph,
    /// Flat list of repositories.
    List,
    /// Detailed view of a single repository.
    Detail,
    /// What-if scenario analysis.
    Scenario,
    /// PanLL panel integration view.
    PanLL,
}

impl fmt::Display for ViewMode {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            ViewMode::Graph => write!(f, "GRAPH"),
            ViewMode::List => write!(f, "LIST"),
            ViewMode::Detail => write!(f, "DETAIL"),
            ViewMode::Scenario => write!(f, "SCENARIO"),
            ViewMode::PanLL => write!(f, "PANLL"),
        }
    }
}

/// Aspect filter for narrowing the displayed data.
///
/// Mirrors Ada `type Aspect_Filter is (All_Aspects, Security, Reliability,
///   Performance, Supply_Chain, Compliance)`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum AspectFilter {
    /// Show all aspects (no filter).
    All,
    /// Security-related aspects only.
    Security,
    /// Reliability-related aspects only.
    Reliability,
    /// Performance-related aspects only.
    Performance,
    /// Supply chain aspects only.
    SupplyChain,
    /// Compliance aspects only.
    Compliance,
}

impl fmt::Display for AspectFilter {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            AspectFilter::All => write!(f, "ALL"),
            AspectFilter::Security => write!(f, "SECURITY"),
            AspectFilter::Reliability => write!(f, "RELIABILITY"),
            AspectFilter::Performance => write!(f, "PERFORMANCE"),
            AspectFilter::SupplyChain => write!(f, "SUPPLY-CHAIN"),
            AspectFilter::Compliance => write!(f, "COMPLIANCE"),
        }
    }
}

/// PanLL connection state.
///
/// Mirrors Ada `type PanLL_Status is (PanLL_Disconnected, PanLL_Connecting,
///   PanLL_Connected, PanLL_Error)`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum PanLLStatus {
    /// Not connected to PanLL.
    Disconnected,
    /// Connection attempt in progress.
    Connecting,
    /// Successfully connected to PanLL.
    Connected,
    /// Connection error occurred.
    Error,
}

impl fmt::Display for PanLLStatus {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PanLLStatus::Disconnected => write!(f, "[-]"),
            PanLLStatus::Connecting => write!(f, "[...]"),
            PanLLStatus::Connected => write!(f, "[OK]"),
            PanLLStatus::Error => write!(f, "[ERR]"),
        }
    }
}

/// PanLL panel target for display routing.
///
/// Mirrors Ada `type PanLL_Panel is (Panel_L, Panel_N, Panel_W)`.
#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
pub enum PanLLPanel {
    /// Panel-L: Ecosystem Constraints.
    L,
    /// Panel-N: Ecosystem Health Reasoning (Neural).
    N,
    /// Panel-W: Ecosystem Barycentre (Workspace).
    W,
}

impl fmt::Display for PanLLPanel {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            PanLLPanel::L => write!(f, "L:Constraints"),
            PanLLPanel::N => write!(f, "N:Reasoning"),
            PanLLPanel::W => write!(f, "W:Barycentre"),
        }
    }
}

// =============================================================================
// AppState — mirrors Ada `App_State` record with Dynamic_Predicate
// =============================================================================

/// Core application state for the TUI.
///
/// Mirrors the Ada record:
/// ```ada
/// type App_State is record
///    Width, Height    : Screen dimensions
///    Cursor_X, Y      : Current cursor position
///    Mode             : View_Mode
///    Filter           : Aspect_Filter
///    Repo_Count       : Natural range 0..Max_Repos
///    Edge_Count       : Natural range 0..Max_Edges
///    Selected         : Natural
///    Running          : Boolean
///    PanLL            : PanLL_Status
///    Active_Panel     : PanLL_Panel
/// end record
///   with Dynamic_Predicate =>
///     Cursor_X <= Width and Cursor_Y <= Height and Selected <= Repo_Count;
/// ```
///
/// The Dynamic_Predicate is enforced by:
/// - The `new()` constructor (validates all fields).
/// - `debug_assert!` calls in every mutating method.
/// - The `check_invariant()` method for explicit verification.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct AppState {
    /// Terminal width in columns. Range: `1..=MAX_WIDTH`.
    width: u16,
    /// Terminal height in rows. Range: `1..=MAX_HEIGHT`.
    height: u16,
    /// Cursor X position. Invariant: `1 <= cursor_x <= width`.
    cursor_x: u16,
    /// Cursor Y position. Invariant: `1 <= cursor_y <= height`.
    cursor_y: u16,
    /// Current view mode.
    mode: ViewMode,
    /// Active aspect filter.
    filter: AspectFilter,
    /// Number of repositories loaded. Range: `0..=MAX_REPOS`.
    repo_count: u32,
    /// Number of edges loaded. Range: `0..=MAX_EDGES`.
    edge_count: u32,
    /// Currently selected repository index. Invariant: `selected <= repo_count`.
    selected: u32,
    /// Whether the application is running (main loop guard).
    running: bool,
    /// PanLL connection status.
    panll: PanLLStatus,
    /// Active PanLL panel.
    active_panel: PanLLPanel,
}

impl AppState {
    // =========================================================================
    // Constructor — mirrors Ada `Initialize` function
    // =========================================================================

    /// Create a new `AppState` with validated dimensions.
    ///
    /// Mirrors Ada `Initialize`:
    /// ```ada
    /// function Initialize (Width : Screen_Width; Height : Screen_Height)
    ///   return App_State
    ///   with Post => Initialize'Result.Running and
    ///                Initialize'Result.Width = Width and
    ///                Initialize'Result.Height = Height;
    /// ```
    ///
    /// # Panics (debug builds)
    ///
    /// Panics if `width` or `height` are outside their valid ranges.
    pub fn new(width: u16, height: u16) -> Self {
        // SPARK Pre-condition: Screen_Width range 1..Max_Width
        debug_assert!(
            width >= 1 && width <= MAX_WIDTH,
            "SPARK contract violation: width {} not in 1..={}",
            width,
            MAX_WIDTH
        );
        // SPARK Pre-condition: Screen_Height range 1..Max_Height
        debug_assert!(
            height >= 1 && height <= MAX_HEIGHT,
            "SPARK contract violation: height {} not in 1..={}",
            height,
            MAX_HEIGHT
        );

        let state = Self {
            width: width.clamp(1, MAX_WIDTH),
            height: height.clamp(1, MAX_HEIGHT),
            cursor_x: 1,
            cursor_y: 1,
            mode: ViewMode::Graph,
            filter: AspectFilter::All,
            repo_count: 0,
            edge_count: 0,
            selected: 0,
            running: true,
            panll: PanLLStatus::Disconnected,
            active_panel: PanLLPanel::W,
        };

        // SPARK Post-condition: Initialize'Result.Running = True
        debug_assert!(state.running, "SPARK post: state must be running after init");
        // SPARK Post-condition: Initialize'Result.Width = Width
        debug_assert_eq!(state.width, width.clamp(1, MAX_WIDTH));
        // SPARK Post-condition: Initialize'Result.Height = Height
        debug_assert_eq!(state.height, height.clamp(1, MAX_HEIGHT));
        // Dynamic_Predicate: full invariant check
        debug_assert!(state.check_invariant(), "SPARK invariant violated after init");

        state
    }

    // =========================================================================
    // Invariant check — mirrors Ada Dynamic_Predicate
    // =========================================================================

    /// Verify the SPARK Dynamic_Predicate invariant:
    ///   `cursor_x <= width AND cursor_y <= height AND selected <= repo_count`
    ///
    /// Returns `true` if all invariants hold. Called in debug builds after
    /// every mutation to mirror SPARK's automatic predicate checking.
    #[inline]
    pub fn check_invariant(&self) -> bool {
        self.cursor_x >= 1
            && self.cursor_x <= self.width
            && self.cursor_y >= 1
            && self.cursor_y <= self.height
            && self.selected <= self.repo_count
            && self.width >= 1
            && self.width <= MAX_WIDTH
            && self.height >= 1
            && self.height <= MAX_HEIGHT
            && self.repo_count <= MAX_REPOS
            && self.edge_count <= MAX_EDGES
    }

    // =========================================================================
    // Input handling — mirrors Ada `Handle_Input` procedure
    // =========================================================================

    /// Process a single key input character, updating state accordingly.
    ///
    /// Mirrors Ada `Handle_Input`:
    /// ```ada
    /// procedure Handle_Input (State : in out App_State; Key : Character)
    ///   with Pre  => State.Running,
    ///        Post => State.Cursor_X <= State.Width and
    ///                State.Cursor_Y <= State.Height;
    /// ```
    pub fn handle_input(&mut self, key: char) {
        // SPARK Pre-condition: State.Running
        debug_assert!(self.running, "SPARK pre: handle_input requires state.running");

        match key {
            // Quit
            'q' | 'Q' => {
                self.running = false;
            }

            // Navigation — left (vim 'h' or arrow)
            'h' => {
                if self.cursor_x > 1 {
                    self.cursor_x -= 1;
                }
            }

            // Navigation — right (vim 'l' or arrow)
            'l' => {
                if self.cursor_x < self.width {
                    self.cursor_x += 1;
                }
            }

            // Navigation — up (vim 'k' or arrow)
            'k' => {
                if self.cursor_y > 1 {
                    self.cursor_y -= 1;
                }
            }

            // Navigation — down (vim 'j' or arrow)
            'j' => {
                if self.cursor_y < self.height {
                    self.cursor_y += 1;
                }
            }

            // View mode switching (1-5)
            '1' => self.mode = ViewMode::Graph,
            '2' => self.mode = ViewMode::List,
            '3' => self.mode = ViewMode::Detail,
            '4' => self.mode = ViewMode::Scenario,
            '5' => self.mode = ViewMode::PanLL,

            // PanLL panel switching
            'L' => self.active_panel = PanLLPanel::L,
            'W' => self.active_panel = PanLLPanel::W,
            'M' => self.active_panel = PanLLPanel::N, // M for Machine (Neural)

            // PanLL connect/disconnect toggle
            'c' => match self.panll {
                PanLLStatus::Disconnected | PanLLStatus::Error => {
                    self.panll = PanLLStatus::Connecting;
                }
                PanLLStatus::Connected => {
                    self.panll = PanLLStatus::Disconnected;
                }
                PanLLStatus::Connecting => {
                    // Wait for connection attempt to finish (no-op, mirrors Ada null)
                }
            },

            // Aspect filter shortcuts
            'a' => self.filter = AspectFilter::All,
            's' => self.filter = AspectFilter::Security,
            'r' => self.filter = AspectFilter::Reliability,
            'p' => self.filter = AspectFilter::Performance,

            // Selection navigation
            'n' => {
                if self.selected < self.repo_count {
                    self.selected += 1;
                }
            }
            'N' => {
                if self.selected > 0 {
                    self.selected -= 1;
                }
            }

            // Ignore unknown keys (mirrors Ada `when others => null`)
            _ => {}
        }

        // SPARK Post-condition: Cursor_X <= Width and Cursor_Y <= Height
        debug_assert!(
            self.cursor_x <= self.width,
            "SPARK post: cursor_x {} > width {}",
            self.cursor_x,
            self.width
        );
        debug_assert!(
            self.cursor_y <= self.height,
            "SPARK post: cursor_y {} > height {}",
            self.cursor_y,
            self.height
        );
        // Full invariant
        debug_assert!(
            self.check_invariant(),
            "SPARK invariant violated after handle_input"
        );
    }

    // =========================================================================
    // Shutdown — mirrors Ada `Shutdown` procedure
    // =========================================================================

    /// Shut down the application by setting `running` to `false`.
    ///
    /// Mirrors Ada `Shutdown`:
    /// ```ada
    /// procedure Shutdown (State : in out App_State)
    ///   with Post => not State.Running;
    /// ```
    pub fn shutdown(&mut self) {
        self.running = false;

        // SPARK Post-condition: not State.Running
        debug_assert!(
            !self.running,
            "SPARK post: running must be false after shutdown"
        );
    }

    // =========================================================================
    // Accessors — public read access to private fields
    // =========================================================================

    /// Terminal width in columns.
    #[inline]
    pub fn width(&self) -> u16 {
        self.width
    }

    /// Terminal height in rows.
    #[inline]
    pub fn height(&self) -> u16 {
        self.height
    }

    /// Current cursor X position (1-based).
    #[inline]
    pub fn cursor_x(&self) -> u16 {
        self.cursor_x
    }

    /// Current cursor Y position (1-based).
    #[inline]
    pub fn cursor_y(&self) -> u16 {
        self.cursor_y
    }

    /// Current view mode.
    #[inline]
    pub fn mode(&self) -> ViewMode {
        self.mode
    }

    /// Active aspect filter.
    #[inline]
    pub fn filter(&self) -> AspectFilter {
        self.filter
    }

    /// Number of loaded repositories.
    #[inline]
    pub fn repo_count(&self) -> u32 {
        self.repo_count
    }

    /// Number of loaded edges.
    #[inline]
    pub fn edge_count(&self) -> u32 {
        self.edge_count
    }

    /// Index of the currently selected repository.
    #[inline]
    pub fn selected(&self) -> u32 {
        self.selected
    }

    /// Whether the main loop is still running.
    #[inline]
    pub fn is_running(&self) -> bool {
        self.running
    }

    /// PanLL connection status.
    #[inline]
    pub fn panll_status(&self) -> PanLLStatus {
        self.panll
    }

    /// Active PanLL panel.
    #[inline]
    pub fn active_panel(&self) -> PanLLPanel {
        self.active_panel
    }

    // =========================================================================
    // Mutators with invariant enforcement
    // =========================================================================

    /// Update repository and edge counts (e.g., after loading data).
    ///
    /// Values are clamped to their maximum bounds to preserve the SPARK
    /// subtype constraints. `selected` is also clamped to the new `repo_count`.
    pub fn set_counts(&mut self, repos: u32, edges: u32) {
        self.repo_count = repos.min(MAX_REPOS);
        self.edge_count = edges.min(MAX_EDGES);
        // Preserve invariant: selected <= repo_count
        if self.selected > self.repo_count {
            self.selected = self.repo_count;
        }
        debug_assert!(
            self.check_invariant(),
            "SPARK invariant violated after set_counts"
        );
    }

    /// Resize the terminal dimensions, clamping cursor to new bounds.
    ///
    /// Preserves the Dynamic_Predicate by adjusting cursor positions.
    pub fn resize(&mut self, width: u16, height: u16) {
        self.width = width.clamp(1, MAX_WIDTH);
        self.height = height.clamp(1, MAX_HEIGHT);
        // Preserve invariant: cursor within bounds
        self.cursor_x = self.cursor_x.clamp(1, self.width);
        self.cursor_y = self.cursor_y.clamp(1, self.height);
        debug_assert!(
            self.check_invariant(),
            "SPARK invariant violated after resize"
        );
    }

    /// Set PanLL connection status directly (for async connection callbacks).
    pub fn set_panll_status(&mut self, status: PanLLStatus) {
        self.panll = status;
    }
}

// =============================================================================
// Tests — mirrors SPARK Ghost properties and proof obligations
// =============================================================================

#[cfg(test)]
mod tests {
    use super::*;

    /// SPARK proof: Initialize post-conditions hold.
    #[test]
    fn test_initialize_postconditions() {
        let state = AppState::new(80, 24);
        assert!(state.is_running(), "Post: Initialize'Result.Running");
        assert_eq!(state.width(), 80, "Post: Initialize'Result.Width = Width");
        assert_eq!(state.height(), 24, "Post: Initialize'Result.Height = Height");
        assert!(state.check_invariant(), "Dynamic_Predicate holds after init");
    }

    /// SPARK proof: Cursor stays within bounds after all navigation inputs.
    #[test]
    fn test_cursor_bounds_after_navigation() {
        let mut state = AppState::new(10, 10);

        // Move to boundary
        for _ in 0..20 {
            state.handle_input('l'); // right
        }
        assert!(
            state.cursor_x() <= state.width(),
            "Post: Cursor_X <= Width after rightward movement"
        );

        for _ in 0..20 {
            state.handle_input('j'); // down
        }
        assert!(
            state.cursor_y() <= state.height(),
            "Post: Cursor_Y <= Height after downward movement"
        );

        // Move past lower boundary
        for _ in 0..20 {
            state.handle_input('h'); // left
        }
        assert!(
            state.cursor_x() >= 1,
            "Post: Cursor_X >= 1 after leftward movement"
        );

        for _ in 0..20 {
            state.handle_input('k'); // up
        }
        assert!(
            state.cursor_y() >= 1,
            "Post: Cursor_Y >= 1 after upward movement"
        );

        assert!(state.check_invariant(), "Dynamic_Predicate holds after navigation");
    }

    /// SPARK proof: Shutdown post-condition.
    #[test]
    fn test_shutdown_postcondition() {
        let mut state = AppState::new(80, 24);
        assert!(state.is_running());
        state.shutdown();
        assert!(!state.is_running(), "Post: not State.Running after Shutdown");
    }

    /// SPARK proof: Selected never exceeds Repo_Count.
    #[test]
    fn test_selected_bounded_by_repo_count() {
        let mut state = AppState::new(80, 24);
        state.set_counts(3, 5);

        // Try to select beyond repo_count
        for _ in 0..10 {
            state.handle_input('n'); // next
        }
        assert!(
            state.selected() <= state.repo_count(),
            "Invariant: Selected <= Repo_Count"
        );

        // Move back past zero
        for _ in 0..10 {
            state.handle_input('N'); // previous
        }
        assert_eq!(state.selected(), 0, "Selected bottoms out at 0");
        assert!(state.check_invariant());
    }

    /// SPARK proof: View mode changes are exhaustive.
    #[test]
    fn test_view_mode_switching() {
        let mut state = AppState::new(80, 24);

        state.handle_input('1');
        assert_eq!(state.mode(), ViewMode::Graph);
        state.handle_input('2');
        assert_eq!(state.mode(), ViewMode::List);
        state.handle_input('3');
        assert_eq!(state.mode(), ViewMode::Detail);
        state.handle_input('4');
        assert_eq!(state.mode(), ViewMode::Scenario);
        state.handle_input('5');
        assert_eq!(state.mode(), ViewMode::PanLL);
    }

    /// SPARK proof: PanLL state machine transitions.
    #[test]
    fn test_panll_state_machine() {
        let mut state = AppState::new(80, 24);

        // Disconnected -> Connecting
        assert_eq!(state.panll_status(), PanLLStatus::Disconnected);
        state.handle_input('c');
        assert_eq!(state.panll_status(), PanLLStatus::Connecting);

        // Connecting -> Connecting (no-op, mirrors Ada null)
        state.handle_input('c');
        assert_eq!(state.panll_status(), PanLLStatus::Connecting);

        // Simulate successful connection
        state.set_panll_status(PanLLStatus::Connected);
        assert_eq!(state.panll_status(), PanLLStatus::Connected);

        // Connected -> Disconnected
        state.handle_input('c');
        assert_eq!(state.panll_status(), PanLLStatus::Disconnected);

        // Error -> Connecting (retry)
        state.set_panll_status(PanLLStatus::Error);
        state.handle_input('c');
        assert_eq!(state.panll_status(), PanLLStatus::Connecting);
    }

    /// SPARK proof: Panel switching only affects active_panel.
    #[test]
    fn test_panel_switching() {
        let mut state = AppState::new(80, 24);

        state.handle_input('L');
        assert_eq!(state.active_panel(), PanLLPanel::L);
        state.handle_input('M');
        assert_eq!(state.active_panel(), PanLLPanel::N);
        state.handle_input('W');
        assert_eq!(state.active_panel(), PanLLPanel::W);
    }

    /// SPARK proof: Resize preserves invariant by clamping cursor.
    #[test]
    fn test_resize_clamps_cursor() {
        let mut state = AppState::new(80, 24);

        // Move cursor to edge
        for _ in 0..79 {
            state.handle_input('l');
        }
        assert_eq!(state.cursor_x(), 80);

        // Shrink — cursor must be clamped
        state.resize(40, 12);
        assert!(
            state.cursor_x() <= state.width(),
            "Cursor clamped after resize"
        );
        assert!(state.check_invariant());
    }

    /// SPARK proof: set_counts clamps selected when repo_count shrinks.
    #[test]
    fn test_set_counts_clamps_selected() {
        let mut state = AppState::new(80, 24);
        state.set_counts(10, 20);

        // Select item 8
        for _ in 0..8 {
            state.handle_input('n');
        }
        assert_eq!(state.selected(), 8);

        // Shrink repo count below selected
        state.set_counts(3, 5);
        assert!(
            state.selected() <= state.repo_count(),
            "selected clamped when repo_count shrinks"
        );
        assert!(state.check_invariant());
    }

    /// SPARK proof: Unknown keys do not violate invariant.
    #[test]
    fn test_unknown_key_preserves_invariant() {
        let mut state = AppState::new(80, 24);
        state.handle_input('z');
        state.handle_input('!');
        state.handle_input('\x00');
        assert!(state.check_invariant());
    }
}
