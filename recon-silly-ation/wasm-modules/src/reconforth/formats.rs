// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ReconForth format detection and parsing
//
// This module provides format detection and basic AST extraction
// for document content, compatible with formatrix-docs.

use super::types::Error;
use serde::{Deserialize, Serialize};

/// Supported document formats
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Format {
    PlainText,
    Markdown,
    AsciiDoc,
    Djot,
    OrgMode,
    ReStructuredText,
    Typst,
    Unknown,
}

impl Format {
    /// Get format name as string
    pub fn as_str(&self) -> &'static str {
        match self {
            Format::PlainText => "txt",
            Format::Markdown => "md",
            Format::AsciiDoc => "adoc",
            Format::Djot => "djot",
            Format::OrgMode => "org",
            Format::ReStructuredText => "rst",
            Format::Typst => "typ",
            Format::Unknown => "unknown",
        }
    }

    /// Parse format from file extension
    pub fn from_extension(ext: &str) -> Self {
        match ext.to_lowercase().as_str() {
            "txt" | "text" => Format::PlainText,
            "md" | "markdown" => Format::Markdown,
            "adoc" | "asciidoc" => Format::AsciiDoc,
            "djot" => Format::Djot,
            "org" => Format::OrgMode,
            "rst" => Format::ReStructuredText,
            "typ" => Format::Typst,
            _ => Format::Unknown,
        }
    }
}

/// Document structure element (simplified AST)
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum Element {
    /// Heading with level (1-6)
    Heading(u8, String),
    /// Paragraph text
    Paragraph(String),
    /// Code block with optional language
    CodeBlock(Option<String>, String),
    /// List (ordered or unordered)
    List(bool, Vec<String>),
    /// Block quote
    Quote(String),
    /// Link with text and URL
    Link(String, String),
    /// Image with alt text and URL
    Image(String, String),
    /// Horizontal rule
    Rule,
    /// Raw content that couldn't be parsed
    Raw(String),
}

/// Parsed document structure
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DocumentStructure {
    pub format: Format,
    pub title: Option<String>,
    pub elements: Vec<Element>,
    pub headings: Vec<(u8, String)>,
    pub links: Vec<(String, String)>,
    pub code_blocks: Vec<(Option<String>, String)>,
}

impl Default for DocumentStructure {
    fn default() -> Self {
        DocumentStructure {
            format: Format::Unknown,
            title: None,
            elements: Vec::new(),
            headings: Vec::new(),
            links: Vec::new(),
            code_blocks: Vec::new(),
        }
    }
}

/// Detect format from content heuristics
pub fn detect_format(content: &str) -> Format {
    let trimmed = content.trim();

    // Check for org-mode markers
    if trimmed.starts_with("#+") || trimmed.contains("\n#+") {
        return Format::OrgMode;
    }

    // Check for org-mode headings
    if trimmed.starts_with("* ") || trimmed.contains("\n* ") {
        // Could be org-mode, check for other markers
        if trimmed.contains("#+TITLE:") || trimmed.contains("#+AUTHOR:") {
            return Format::OrgMode;
        }
    }

    // Check for AsciiDoc markers
    if trimmed.starts_with("= ")
        || trimmed.starts_with(":toc:")
        || trimmed.contains("\n= ")
        || trimmed.contains("----\n")
    {
        return Format::AsciiDoc;
    }

    // Check for Typst markers
    if trimmed.starts_with("#") && (trimmed.contains("#{") || trimmed.contains("#let")) {
        return Format::Typst;
    }

    // Check for Djot markers (similar to md but with different syntax)
    if trimmed.contains("{.") || trimmed.contains("[^") {
        return Format::Djot;
    }

    // Check for RST markers
    if trimmed.contains(".. ") && (trimmed.contains("::") || trimmed.contains(".. code-block::")) {
        return Format::ReStructuredText;
    }
    if trimmed.lines().any(|l| {
        l.chars().all(|c| c == '=' || c == '-' || c == '~')
            && l.len() > 3
    }) {
        // Check for RST-style underlines
        let lines: Vec<&str> = trimmed.lines().collect();
        for i in 1..lines.len() {
            if lines[i].chars().all(|c| c == '=' || c == '-' || c == '~')
                && lines[i].len() >= lines[i - 1].len()
            {
                return Format::ReStructuredText;
            }
        }
    }

    // Check for Markdown markers (most permissive, check last)
    if trimmed.starts_with("# ")
        || trimmed.starts_with("## ")
        || trimmed.contains("\n# ")
        || trimmed.contains("```")
        || trimmed.contains("[](")
        || trimmed.contains("![")
    {
        return Format::Markdown;
    }

    // Plain text if no markup detected
    Format::PlainText
}

/// Parse markdown content
pub fn parse_markdown(content: &str) -> Result<DocumentStructure, Error> {
    use comrak::{parse_document, Arena, Options};
    use comrak::nodes::NodeValue;

    let arena = Arena::new();
    let options = Options::default();
    let root = parse_document(&arena, content, &options);

    let mut structure = DocumentStructure {
        format: Format::Markdown,
        ..Default::default()
    };

    // Walk the AST
    fn walk_node<'a>(
        node: &'a comrak::nodes::AstNode<'a>,
        structure: &mut DocumentStructure,
    ) {
        match &node.data.borrow().value {
            NodeValue::Heading(heading) => {
                let text = get_node_text(node);
                structure.headings.push((heading.level, text.clone()));
                structure.elements.push(Element::Heading(heading.level, text.clone()));
                if structure.title.is_none() && heading.level == 1 {
                    structure.title = Some(text);
                }
            }
            NodeValue::Paragraph => {
                let text = get_node_text(node);
                if !text.is_empty() {
                    structure.elements.push(Element::Paragraph(text));
                }
            }
            NodeValue::CodeBlock(cb) => {
                let lang = if cb.info.is_empty() {
                    None
                } else {
                    Some(cb.info.clone())
                };
                structure.code_blocks.push((lang.clone(), cb.literal.clone()));
                structure.elements.push(Element::CodeBlock(lang, cb.literal.clone()));
            }
            NodeValue::Link(link) => {
                let text = get_node_text(node);
                structure.links.push((text.clone(), link.url.clone()));
                structure.elements.push(Element::Link(text, link.url.clone()));
            }
            NodeValue::Image(img) => {
                let alt = get_node_text(node);
                structure.elements.push(Element::Image(alt, img.url.clone()));
            }
            NodeValue::BlockQuote => {
                let text = get_node_text(node);
                structure.elements.push(Element::Quote(text));
            }
            NodeValue::List(_) => {
                let items: Vec<String> = node
                    .children()
                    .map(|c| get_node_text(c))
                    .collect();
                structure.elements.push(Element::List(false, items));
            }
            NodeValue::ThematicBreak => {
                structure.elements.push(Element::Rule);
            }
            _ => {}
        }

        for child in node.children() {
            walk_node(child, structure);
        }
    }

    fn get_node_text<'a>(node: &'a comrak::nodes::AstNode<'a>) -> String {
        let mut text = String::new();
        collect_text(node, &mut text);
        text
    }

    fn collect_text<'a>(node: &'a comrak::nodes::AstNode<'a>, text: &mut String) {
        match &node.data.borrow().value {
            NodeValue::Text(t) => text.push_str(t),
            NodeValue::Code(c) => text.push_str(&c.literal),
            NodeValue::SoftBreak | NodeValue::LineBreak => text.push(' '),
            _ => {
                for child in node.children() {
                    collect_text(child, text);
                }
            }
        }
    }

    walk_node(root, &mut structure);
    Ok(structure)
}

/// Parse djot content
pub fn parse_djot(content: &str) -> Result<DocumentStructure, Error> {
    use jotdown::{Parser, Event, Container};

    let mut structure = DocumentStructure {
        format: Format::Djot,
        ..Default::default()
    };

    let parser = Parser::new(content);
    let mut current_heading_level: Option<u8> = None;
    let mut current_text = String::new();

    for event in parser {
        match event {
            Event::Start(Container::Heading { level, .. }, _) => {
                current_heading_level = Some(level as u8);
                current_text.clear();
            }
            Event::End(Container::Heading { level, .. }) => {
                let text = current_text.trim().to_string();
                structure.headings.push((level as u8, text.clone()));
                structure.elements.push(Element::Heading(level as u8, text.clone()));
                if structure.title.is_none() && level == 1 {
                    structure.title = Some(text);
                }
                current_heading_level = None;
            }
            Event::Start(Container::Paragraph, _) => {
                current_text.clear();
            }
            Event::End(Container::Paragraph) => {
                let text = current_text.trim().to_string();
                if !text.is_empty() && current_heading_level.is_none() {
                    structure.elements.push(Element::Paragraph(text));
                }
            }
            Event::Start(Container::CodeBlock { language }, _) => {
                current_text.clear();
            }
            Event::End(Container::CodeBlock { language }) => {
                let lang = if language.is_empty() {
                    None
                } else {
                    Some(language.to_string())
                };
                structure.code_blocks.push((lang.clone(), current_text.clone()));
                structure.elements.push(Element::CodeBlock(lang, current_text.clone()));
            }
            Event::Start(Container::Link(url, _), _) => {
                current_text.clear();
            }
            Event::End(Container::Link(url, _)) => {
                let text = current_text.trim().to_string();
                structure.links.push((text.clone(), url.to_string()));
            }
            Event::Str(s) => {
                current_text.push_str(&s);
            }
            _ => {}
        }
    }

    Ok(structure)
}

/// Parse org-mode content
pub fn parse_orgmode(content: &str) -> Result<DocumentStructure, Error> {
    use orgize::{Org, Element as OrgElement};

    let org = Org::parse(content);
    let mut structure = DocumentStructure {
        format: Format::OrgMode,
        ..Default::default()
    };

    // Extract title from #+TITLE: directive
    for line in content.lines() {
        if line.to_uppercase().starts_with("#+TITLE:") {
            structure.title = Some(line[8..].trim().to_string());
            break;
        }
    }

    // Walk org document
    for event in org.iter() {
        match event {
            orgize::Event::Start(OrgElement::Title(title)) => {
                let text = title.raw.trim().to_string();
                let level = title.level as u8;
                structure.headings.push((level, text.clone()));
                structure.elements.push(Element::Heading(level, text.clone()));
                if structure.title.is_none() && level == 1 {
                    structure.title = Some(text);
                }
            }
            orgize::Event::Start(OrgElement::SourceBlock(block)) => {
                let lang = if block.language.is_empty() {
                    None
                } else {
                    Some(block.language.to_string())
                };
                structure.code_blocks.push((lang.clone(), block.contents.to_string()));
                structure.elements.push(Element::CodeBlock(lang, block.contents.to_string()));
            }
            orgize::Event::Start(OrgElement::Link(link)) => {
                let text = link.desc.as_ref().map_or_else(
                    || link.path.to_string(),
                    |d| d.to_string(),
                );
                structure.links.push((text.clone(), link.path.to_string()));
            }
            orgize::Event::Start(OrgElement::QuoteBlock(_)) => {
                // Quote blocks are containers, content comes from nested events
            }
            _ => {}
        }
    }

    Ok(structure)
}

/// Parse document content with format auto-detection
pub fn parse_content(content: &str) -> Result<DocumentStructure, Error> {
    let format = detect_format(content);
    parse_content_with_format(content, format)
}

/// Parse document content with specified format
pub fn parse_content_with_format(content: &str, format: Format) -> Result<DocumentStructure, Error> {
    match format {
        Format::Markdown => parse_markdown(content),
        Format::Djot => parse_djot(content),
        Format::OrgMode => parse_orgmode(content),
        Format::PlainText => Ok(DocumentStructure {
            format: Format::PlainText,
            title: content.lines().next().map(|s| s.to_string()),
            elements: content
                .split("\n\n")
                .filter(|s| !s.trim().is_empty())
                .map(|s| Element::Paragraph(s.trim().to_string()))
                .collect(),
            ..Default::default()
        }),
        _ => Err(Error::RuntimeError(format!(
            "Format {:?} not yet supported",
            format
        ))),
    }
}

/// Check if document has a specific heading
pub fn has_heading(structure: &DocumentStructure, text: &str) -> bool {
    structure.headings.iter().any(|(_, h)| h.contains(text))
}

/// Check if document has a code block with a specific language
pub fn has_code_language(structure: &DocumentStructure, lang: &str) -> bool {
    structure.code_blocks.iter().any(|(l, _)| {
        l.as_ref().map_or(false, |l| l == lang)
    })
}

/// Get all external links from document
pub fn get_external_links(structure: &DocumentStructure) -> Vec<&str> {
    structure
        .links
        .iter()
        .filter(|(_, url)| url.starts_with("http://") || url.starts_with("https://"))
        .map(|(_, url)| url.as_str())
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_detect_markdown() {
        let content = "# Hello World\n\nThis is a test.";
        assert_eq!(detect_format(content), Format::Markdown);
    }

    #[test]
    fn test_detect_orgmode() {
        let content = "#+TITLE: Test\n* Hello\n** World";
        assert_eq!(detect_format(content), Format::OrgMode);
    }

    #[test]
    fn test_detect_asciidoc() {
        let content = "= Document Title\n:toc:\n\n== Section";
        assert_eq!(detect_format(content), Format::AsciiDoc);
    }

    #[test]
    fn test_parse_markdown() {
        let content = "# Title\n\nParagraph.\n\n## Section\n\n```rust\ncode\n```";
        let structure = parse_markdown(content).unwrap();
        assert_eq!(structure.title, Some("Title".to_string()));
        assert_eq!(structure.headings.len(), 2);
        assert_eq!(structure.code_blocks.len(), 1);
    }

    #[test]
    fn test_parse_orgmode() {
        let content = "#+TITLE: Test Doc\n* Heading 1\n** Heading 2\n#+BEGIN_SRC rust\ncode\n#+END_SRC";
        let structure = parse_orgmode(content).unwrap();
        assert_eq!(structure.title, Some("Test Doc".to_string()));
        assert!(structure.headings.len() >= 2);
    }
}
