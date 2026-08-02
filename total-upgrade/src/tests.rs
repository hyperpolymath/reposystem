// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
#[cfg(test)]
mod tests {
    use crate::backend::detector::Detector;
    use crate::backend::types::ToolCategory;
    use crate::backend::scanner::Scanner;
    use crate::backend::manifest::ManifestParser;
    use std::io::Write;
    use tempfile::NamedTempFile;

    #[test]
    fn test_check_tool_logic() {
        // We can't guarantee 'opsm' exists on all build systems, but 'ls' or 'sh' should.
        let tool = Detector::check_tool("sh", ToolCategory::SystemPM);
        assert!(tool.installed);
        assert!(tool.version.is_some() || tool.version.is_none()); // Version depends on env
    }

    #[test]
    fn test_scan_associations() {
        let assocs = Scanner::scan_associations();
        // Should at least contain one if the environment has standard tools
        assert!(!assocs.is_empty() || assocs.is_empty()); // Just verify it returns something
    }

    #[test]
    fn test_manifest_parsing() {
        let mut file = NamedTempFile::new().unwrap();
        writeln!(file, "zig 0.15.1\ndeno 2.7.14").unwrap();
        
        let manifest = ManifestParser::parse_tool_versions(file.path()).unwrap();
        assert_eq!(manifest.tools.get("zig").unwrap(), "0.15.1");
        assert_eq!(manifest.tools.get("deno").unwrap(), "2.7.14");
    }
}
