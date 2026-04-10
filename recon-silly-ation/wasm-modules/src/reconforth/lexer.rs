// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ReconForth lexer - Tokenize ReconForth source code

use super::types::{Error, Token};

/// Lexer for ReconForth programs
pub struct Lexer<'a> {
    input: &'a str,
    pos: usize,
}

impl<'a> Lexer<'a> {
    /// Create new lexer for input string
    pub fn new(input: &'a str) -> Self {
        Lexer { input, pos: 0 }
    }

    /// Tokenize the entire input
    pub fn tokenize(&mut self) -> Result<Vec<Token>, Error> {
        let mut tokens = Vec::new();

        while let Some(token) = self.next_token()? {
            tokens.push(token);
        }

        Ok(tokens)
    }

    /// Get next token
    fn next_token(&mut self) -> Result<Option<Token>, Error> {
        self.skip_whitespace();

        if self.pos >= self.input.len() {
            return Ok(None);
        }

        let ch = self.peek_char().unwrap();

        // Comments: -- to end of line
        if ch == '-' && self.peek_char_at(1) == Some('-') {
            let comment = self.read_until('\n');
            return Ok(Some(Token::Comment(comment)));
        }

        // String literals
        if ch == '"' {
            return Ok(Some(self.read_string()?));
        }

        // Quotation start
        if ch == '[' {
            self.advance();
            return Ok(Some(Token::QuoteStart));
        }

        // Quotation end
        if ch == ']' {
            self.advance();
            return Ok(Some(Token::QuoteEnd));
        }

        // Definition start
        if ch == ':' && self.peek_char_at(1).map_or(true, |c| c.is_whitespace()) {
            self.advance();
            return Ok(Some(Token::DefStart));
        }

        // Definition end
        if ch == ';' {
            self.advance();
            return Ok(Some(Token::DefEnd));
        }

        // Stack effect comment
        if ch == '(' {
            self.advance();
            return Ok(Some(Token::StackEffectStart));
        }

        if ch == ')' {
            self.advance();
            return Ok(Some(Token::StackEffectEnd));
        }

        // Numbers or words
        let word = self.read_word();

        if word.is_empty() {
            return Err(Error::ParseError(format!(
                "Unexpected character: {}",
                ch
            )));
        }

        // Try to parse as number
        if let Ok(n) = word.parse::<i64>() {
            return Ok(Some(Token::Int(n)));
        }

        if let Ok(f) = word.parse::<f64>() {
            return Ok(Some(Token::Float(f)));
        }

        // Boolean literals
        if word == "true" {
            return Ok(Some(Token::Word("true".to_string())));
        }

        if word == "false" {
            return Ok(Some(Token::Word("false".to_string())));
        }

        // Regular word
        Ok(Some(Token::Word(word)))
    }

    /// Peek at current character
    fn peek_char(&self) -> Option<char> {
        self.input[self.pos..].chars().next()
    }

    /// Peek at character at offset
    fn peek_char_at(&self, offset: usize) -> Option<char> {
        self.input[self.pos..].chars().nth(offset)
    }

    /// Advance position by one character
    fn advance(&mut self) {
        if let Some(ch) = self.peek_char() {
            self.pos += ch.len_utf8();
        }
    }

    /// Skip whitespace
    fn skip_whitespace(&mut self) {
        while let Some(ch) = self.peek_char() {
            if ch.is_whitespace() {
                self.advance();
            } else {
                break;
            }
        }
    }

    /// Read until a specific character
    fn read_until(&mut self, end: char) -> String {
        let start = self.pos;
        while let Some(ch) = self.peek_char() {
            if ch == end {
                break;
            }
            self.advance();
        }
        self.input[start..self.pos].to_string()
    }

    /// Read a string literal
    fn read_string(&mut self) -> Result<Token, Error> {
        self.advance(); // Skip opening quote
        let mut result = String::new();

        loop {
            match self.peek_char() {
                None => {
                    return Err(Error::ParseError("Unterminated string".to_string()));
                }
                Some('"') => {
                    self.advance();
                    break;
                }
                Some('\\') => {
                    self.advance();
                    match self.peek_char() {
                        Some('n') => {
                            result.push('\n');
                            self.advance();
                        }
                        Some('t') => {
                            result.push('\t');
                            self.advance();
                        }
                        Some('r') => {
                            result.push('\r');
                            self.advance();
                        }
                        Some('"') => {
                            result.push('"');
                            self.advance();
                        }
                        Some('\\') => {
                            result.push('\\');
                            self.advance();
                        }
                        Some(c) => {
                            result.push(c);
                            self.advance();
                        }
                        None => {
                            return Err(Error::ParseError(
                                "Unterminated escape sequence".to_string(),
                            ));
                        }
                    }
                }
                Some(ch) => {
                    result.push(ch);
                    self.advance();
                }
            }
        }

        Ok(Token::Str(result))
    }

    /// Read a word (identifier or number)
    fn read_word(&mut self) -> String {
        let start = self.pos;

        while let Some(ch) = self.peek_char() {
            // Stop at whitespace or special characters
            if ch.is_whitespace()
                || ch == '['
                || ch == ']'
                || ch == '"'
                || (ch == '(' || ch == ')')
            {
                break;
            }

            // Check for comment start
            if ch == '-' && self.peek_char_at(1) == Some('-') {
                break;
            }

            self.advance();
        }

        self.input[start..self.pos].to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_tokenize_words() {
        let mut lexer = Lexer::new("dup swap drop");
        let tokens = lexer.tokenize().unwrap();

        assert_eq!(tokens.len(), 3);
        assert_eq!(tokens[0], Token::Word("dup".to_string()));
        assert_eq!(tokens[1], Token::Word("swap".to_string()));
        assert_eq!(tokens[2], Token::Word("drop".to_string()));
    }

    #[test]
    fn test_tokenize_numbers() {
        let mut lexer = Lexer::new("42 -17 3.14");
        let tokens = lexer.tokenize().unwrap();

        assert_eq!(tokens.len(), 3);
        assert_eq!(tokens[0], Token::Int(42));
        assert_eq!(tokens[1], Token::Int(-17));
        assert_eq!(tokens[2], Token::Float(3.14));
    }

    #[test]
    fn test_tokenize_string() {
        let mut lexer = Lexer::new("\"hello world\"");
        let tokens = lexer.tokenize().unwrap();

        assert_eq!(tokens.len(), 1);
        assert_eq!(tokens[0], Token::Str("hello world".to_string()));
    }

    #[test]
    fn test_tokenize_quotation() {
        let mut lexer = Lexer::new("[ dup * ]");
        let tokens = lexer.tokenize().unwrap();

        assert_eq!(tokens.len(), 4);
        assert_eq!(tokens[0], Token::QuoteStart);
        assert_eq!(tokens[1], Token::Word("dup".to_string()));
        assert_eq!(tokens[2], Token::Word("*".to_string()));
        assert_eq!(tokens[3], Token::QuoteEnd);
    }

    #[test]
    fn test_tokenize_definition() {
        let mut lexer = Lexer::new(": square dup * ;");
        let tokens = lexer.tokenize().unwrap();

        assert_eq!(tokens.len(), 5);
        assert_eq!(tokens[0], Token::DefStart);
        assert_eq!(tokens[1], Token::Word("square".to_string()));
        assert_eq!(tokens[2], Token::Word("dup".to_string()));
        assert_eq!(tokens[3], Token::Word("*".to_string()));
        assert_eq!(tokens[4], Token::DefEnd);
    }

    #[test]
    fn test_tokenize_comment() {
        let mut lexer = Lexer::new("dup -- this is a comment\nswap");
        let tokens = lexer.tokenize().unwrap();

        assert_eq!(tokens.len(), 3);
        assert_eq!(tokens[0], Token::Word("dup".to_string()));
        assert!(matches!(tokens[1], Token::Comment(_)));
        assert_eq!(tokens[2], Token::Word("swap".to_string()));
    }
}
