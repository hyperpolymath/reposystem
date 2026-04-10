// SPDX-License-Identifier: PMPL-1.0-or-later
//
// ReconForth VM - Virtual machine for executing ReconForth programs

use super::builtins::register_builtins;
use super::lexer::Lexer;
use super::types::{
    Bundle, Dictionary, Document, Error, PackSpec, Token, ValidationMessage,
    ValidationResult, Value, WordDef,
};
use std::collections::HashMap;

/// ReconForth Virtual Machine
pub struct VM {
    /// Data stack
    stack: Vec<Value>,
    /// Return stack (for quotation calls)
    return_stack: Vec<Vec<Token>>,
    /// Word dictionary
    dictionary: Dictionary,
    /// Current bundle being processed
    current_bundle: Option<Bundle>,
    /// Validation results
    validation: ValidationResult,
    /// Debug mode
    debug: bool,
}

impl VM {
    /// Create new VM instance
    pub fn new() -> Self {
        let mut vm = VM {
            stack: Vec::new(),
            return_stack: Vec::new(),
            dictionary: HashMap::new(),
            current_bundle: None,
            validation: ValidationResult::default(),
            debug: false,
        };

        register_builtins(&mut vm);
        vm
    }

    /// Enable/disable debug mode
    pub fn set_debug(&mut self, debug: bool) {
        self.debug = debug;
    }

    /// Load a bundle into the VM
    pub fn load_bundle(&mut self, bundle: Bundle) {
        self.current_bundle = Some(bundle.clone());
        self.push(Value::Bundle(bundle));
    }

    /// Get the current bundle
    pub fn get_bundle(&self) -> Option<&Bundle> {
        self.current_bundle.as_ref()
    }

    /// Push value onto stack
    pub fn push(&mut self, value: Value) {
        if self.debug {
            eprintln!("[DEBUG] push: {:?}", value.type_name());
        }
        self.stack.push(value);
    }

    /// Pop value from stack
    pub fn pop(&mut self) -> Result<Value, Error> {
        self.stack.pop().ok_or_else(|| {
            Error::StackUnderflow("Stack is empty".to_string())
        })
    }

    /// Peek at top of stack
    pub fn peek(&self) -> Option<&Value> {
        self.stack.last()
    }

    /// Get stack depth
    pub fn depth(&self) -> usize {
        self.stack.len()
    }

    /// Pop value and expect specific type
    pub fn pop_int(&mut self) -> Result<i64, Error> {
        let val = self.pop()?;
        val.as_int().ok_or_else(|| Error::TypeError {
            expected: "Int".to_string(),
            got: val.type_name().to_string(),
        })
    }

    /// Pop string from stack
    pub fn pop_str(&mut self) -> Result<String, Error> {
        let val = self.pop()?;
        match val {
            Value::Str(s) => Ok(s),
            Value::Hash(s) => Ok(s),
            _ => Err(Error::TypeError {
                expected: "Str".to_string(),
                got: val.type_name().to_string(),
            }),
        }
    }

    /// Pop bool from stack
    pub fn pop_bool(&mut self) -> Result<bool, Error> {
        let val = self.pop()?;
        val.as_bool().ok_or_else(|| Error::TypeError {
            expected: "Bool".to_string(),
            got: val.type_name().to_string(),
        })
    }

    /// Pop document from stack
    pub fn pop_doc(&mut self) -> Result<Document, Error> {
        let val = self.pop()?;
        match val {
            Value::Doc(d) => Ok(d),
            _ => Err(Error::TypeError {
                expected: "Doc".to_string(),
                got: val.type_name().to_string(),
            }),
        }
    }

    /// Pop bundle from stack
    pub fn pop_bundle(&mut self) -> Result<Bundle, Error> {
        let val = self.pop()?;
        match val {
            Value::Bundle(b) => Ok(b),
            _ => Err(Error::TypeError {
                expected: "Bundle".to_string(),
                got: val.type_name().to_string(),
            }),
        }
    }

    /// Pop pack from stack
    pub fn pop_pack(&mut self) -> Result<PackSpec, Error> {
        let val = self.pop()?;
        match val {
            Value::Pack(p) => Ok(p),
            _ => Err(Error::TypeError {
                expected: "Pack".to_string(),
                got: val.type_name().to_string(),
            }),
        }
    }

    /// Pop quotation from stack
    pub fn pop_quotation(&mut self) -> Result<Vec<Token>, Error> {
        let val = self.pop()?;
        match val {
            Value::Quotation(q) => Ok(q),
            _ => Err(Error::TypeError {
                expected: "Quotation".to_string(),
                got: val.type_name().to_string(),
            }),
        }
    }

    /// Pop list from stack
    pub fn pop_list(&mut self) -> Result<Vec<Value>, Error> {
        let val = self.pop()?;
        match val {
            Value::List(l) => Ok(l),
            _ => Err(Error::TypeError {
                expected: "List".to_string(),
                got: val.type_name().to_string(),
            }),
        }
    }

    /// Register a native word
    pub fn register_native(
        &mut self,
        name: &str,
        func: fn(&mut VM) -> Result<(), Error>,
    ) {
        self.dictionary
            .insert(name.to_string(), WordDef::Native(func));
    }

    /// Define a user word
    pub fn define_word(&mut self, name: &str, body: Vec<Token>) {
        self.dictionary
            .insert(name.to_string(), WordDef::User(body));
    }

    /// Report an error during validation
    pub fn report_error(&mut self, message: String) {
        self.validation.success = false;
        self.validation.errors.push(ValidationMessage::new(message));
    }

    /// Report a warning during validation
    pub fn report_warning(&mut self, message: String) {
        self.validation.warnings.push(ValidationMessage::new(message));
    }

    /// Report a suggestion during validation
    pub fn report_suggestion(&mut self, message: String) {
        self.validation.suggestions.push(ValidationMessage::new(message));
    }

    /// Get validation results
    pub fn get_validation(&self) -> &ValidationResult {
        &self.validation
    }

    /// Reset validation state
    pub fn reset_validation(&mut self) {
        self.validation = ValidationResult::default();
    }

    /// Evaluate ReconForth source code
    pub fn eval(&mut self, source: &str) -> Result<(), Error> {
        let mut lexer = Lexer::new(source);
        let tokens = lexer.tokenize()?;
        self.execute(&tokens)
    }

    /// Execute a sequence of tokens
    pub fn execute(&mut self, tokens: &[Token]) -> Result<(), Error> {
        let mut i = 0;

        while i < tokens.len() {
            let token = &tokens[i];

            match token {
                Token::Int(n) => {
                    self.push(Value::Int(*n));
                }

                Token::Float(f) => {
                    self.push(Value::Float(*f));
                }

                Token::Str(s) => {
                    self.push(Value::Str(s.clone()));
                }

                Token::QuoteStart => {
                    // Collect tokens until QuoteEnd
                    let mut depth = 1;
                    let start = i + 1;
                    i += 1;

                    while i < tokens.len() && depth > 0 {
                        match &tokens[i] {
                            Token::QuoteStart => depth += 1,
                            Token::QuoteEnd => depth -= 1,
                            _ => {}
                        }
                        if depth > 0 {
                            i += 1;
                        }
                    }

                    if depth != 0 {
                        return Err(Error::ParseError(
                            "Unmatched quotation bracket".to_string(),
                        ));
                    }

                    let quotation = tokens[start..i].to_vec();
                    self.push(Value::Quotation(quotation));
                }

                Token::DefStart => {
                    // Read word name
                    i += 1;
                    let name = match tokens.get(i) {
                        Some(Token::Word(w)) => w.clone(),
                        _ => {
                            return Err(Error::ParseError(
                                "Expected word name after :".to_string(),
                            ));
                        }
                    };

                    // Skip stack effect if present
                    i += 1;
                    if matches!(tokens.get(i), Some(Token::StackEffectStart)) {
                        while i < tokens.len()
                            && !matches!(tokens.get(i), Some(Token::StackEffectEnd))
                        {
                            i += 1;
                        }
                        i += 1; // Skip StackEffectEnd
                    }

                    // Collect body until DefEnd
                    let start = i;
                    while i < tokens.len()
                        && !matches!(tokens.get(i), Some(Token::DefEnd))
                    {
                        i += 1;
                    }

                    if !matches!(tokens.get(i), Some(Token::DefEnd)) {
                        return Err(Error::ParseError(
                            "Unterminated word definition".to_string(),
                        ));
                    }

                    let body = tokens[start..i].to_vec();
                    self.define_word(&name, body);
                }

                Token::Word(name) => {
                    self.execute_word(name)?;
                }

                Token::Comment(_) => {
                    // Skip comments
                }

                Token::StackEffectStart
                | Token::StackEffectEnd
                | Token::QuoteEnd
                | Token::DefEnd => {
                    // These are handled by their corresponding start tokens
                }
            }

            i += 1;
        }

        Ok(())
    }

    /// Execute a single word
    fn execute_word(&mut self, name: &str) -> Result<(), Error> {
        if self.debug {
            eprintln!("[DEBUG] exec: {} (depth={})", name, self.depth());
        }

        // Look up word in dictionary
        let word_def = self
            .dictionary
            .get(name)
            .cloned()
            .ok_or_else(|| Error::UndefinedWord(name.to_string()))?;

        match word_def {
            WordDef::Native(func) => func(self),
            WordDef::User(body) => self.execute(&body),
        }
    }

    /// Call a quotation
    pub fn call_quotation(&mut self, quotation: &[Token]) -> Result<(), Error> {
        self.execute(quotation)
    }
}

impl Default for VM {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_push_pop() {
        let mut vm = VM::new();
        vm.push(Value::Int(42));
        let val = vm.pop().unwrap();
        assert!(matches!(val, Value::Int(42)));
    }

    #[test]
    fn test_eval_simple() {
        let mut vm = VM::new();
        vm.eval("5 3 +").unwrap();
        let val = vm.pop_int().unwrap();
        assert_eq!(val, 8);
    }

    #[test]
    fn test_eval_quotation() {
        let mut vm = VM::new();
        vm.eval("5 [ dup * ] call").unwrap();
        let val = vm.pop_int().unwrap();
        assert_eq!(val, 25);
    }

    #[test]
    fn test_define_word() {
        let mut vm = VM::new();
        vm.eval(": square dup * ; 7 square").unwrap();
        let val = vm.pop_int().unwrap();
        assert_eq!(val, 49);
    }
}
