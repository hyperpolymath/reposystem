// SPDX-License-Identifier: MPL-2.0
// Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
// ReconForth builtins - native word definitions
//
// Restored module. `reconforth/mod.rs` declared `mod builtins;` /
// `pub use builtins::register_builtins`, and `vm.rs` calls
// `register_builtins(&mut vm)` from `VM::new()`, but `builtins.rs` was
// never committed (E0583), so the `recon-wasm` crate did not compile.
//
// This restores the core stack-language vocabulary the VM and its tests
// rely on (`+ * dup call` etc.), plus the document-reconciliation helpers
// implied by the typed `VM::pop_*` accessors. All words are total and
// fallible (no `unwrap`/`panic!`) per estate robustness policy.

use super::types::{Error, Value};
use super::vm::VM;

/// Register all built-in native words into a fresh VM dictionary.
pub fn register_builtins(vm: &mut VM) {
    // arithmetic
    vm.register_native("+", w_add);
    vm.register_native("-", w_sub);
    vm.register_native("*", w_mul);
    vm.register_native("/", w_div);
    vm.register_native("mod", w_mod);
    vm.register_native("neg", w_neg);
    // comparison
    vm.register_native("=", w_eq);
    vm.register_native("!=", w_neq);
    vm.register_native("<", w_lt);
    vm.register_native(">", w_gt);
    vm.register_native("<=", w_le);
    vm.register_native(">=", w_ge);
    // boolean
    vm.register_native("and", w_and);
    vm.register_native("or", w_or);
    vm.register_native("not", w_not);
    vm.register_native("true", w_true);
    vm.register_native("false", w_false);
    // stack manipulation
    vm.register_native("dup", w_dup);
    vm.register_native("drop", w_drop);
    vm.register_native("swap", w_swap);
    vm.register_native("over", w_over);
    vm.register_native("rot", w_rot);
    vm.register_native("nip", w_nip);
    vm.register_native("depth", w_depth);
    // control flow
    vm.register_native("call", w_call);
    vm.register_native("if", w_if);
    vm.register_native("ifelse", w_ifelse);
    // validation reporting
    vm.register_native("error!", w_error);
    vm.register_native("warn!", w_warn);
    vm.register_native("suggest!", w_suggest);
    // document-reconciliation helpers
    vm.register_native("count", w_count);
    vm.register_native("doc-type", w_doc_type);
    vm.register_native("is-canonical", w_is_canonical);
}

// ---- arithmetic ----

fn w_add(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Int(a.wrapping_add(b)));
    Ok(())
}

fn w_sub(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Int(a.wrapping_sub(b)));
    Ok(())
}

fn w_mul(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Int(a.wrapping_mul(b)));
    Ok(())
}

fn w_div(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    if b == 0 {
        return Err(Error::RuntimeError("division by zero".to_string()));
    }
    vm.push(Value::Int(a / b));
    Ok(())
}

fn w_mod(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    if b == 0 {
        return Err(Error::RuntimeError("modulo by zero".to_string()));
    }
    vm.push(Value::Int(a % b));
    Ok(())
}

fn w_neg(vm: &mut VM) -> Result<(), Error> {
    let a = vm.pop_int()?;
    vm.push(Value::Int(a.wrapping_neg()));
    Ok(())
}

// ---- comparison ----

fn values_equal(a: &Value, b: &Value) -> bool {
    if let (Some(x), Some(y)) = (a.as_int(), b.as_int()) {
        return x == y;
    }
    if let (Some(x), Some(y)) = (a.as_str(), b.as_str()) {
        return x == y;
    }
    matches!((a, b), (Value::Nil, Value::Nil))
}

fn w_eq(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(Value::Bool(values_equal(&a, &b)));
    Ok(())
}

fn w_neq(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(Value::Bool(!values_equal(&a, &b)));
    Ok(())
}

fn w_lt(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a < b));
    Ok(())
}

fn w_gt(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a > b));
    Ok(())
}

fn w_le(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a <= b));
    Ok(())
}

fn w_ge(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a >= b));
    Ok(())
}

// ---- boolean ----

fn w_and(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_bool()?;
    let a = vm.pop_bool()?;
    vm.push(Value::Bool(a && b));
    Ok(())
}

fn w_or(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_bool()?;
    let a = vm.pop_bool()?;
    vm.push(Value::Bool(a || b));
    Ok(())
}

fn w_not(vm: &mut VM) -> Result<(), Error> {
    let a = vm.pop_bool()?;
    vm.push(Value::Bool(!a));
    Ok(())
}

fn w_true(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::Bool(true));
    Ok(())
}

fn w_false(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::Bool(false));
    Ok(())
}

// ---- stack manipulation ----

fn w_dup(vm: &mut VM) -> Result<(), Error> {
    let v = vm.pop()?;
    vm.push(v.clone());
    vm.push(v);
    Ok(())
}

fn w_drop(vm: &mut VM) -> Result<(), Error> {
    vm.pop()?;
    Ok(())
}

fn w_swap(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(b);
    vm.push(a);
    Ok(())
}

fn w_over(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(a.clone());
    vm.push(b);
    vm.push(a);
    Ok(())
}

fn w_rot(vm: &mut VM) -> Result<(), Error> {
    let c = vm.pop()?;
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(b);
    vm.push(c);
    vm.push(a);
    Ok(())
}

fn w_nip(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let _a = vm.pop()?;
    vm.push(b);
    Ok(())
}

fn w_depth(vm: &mut VM) -> Result<(), Error> {
    let d = vm.depth() as i64;
    vm.push(Value::Int(d));
    Ok(())
}

// ---- control flow ----

fn w_call(vm: &mut VM) -> Result<(), Error> {
    let q = vm.pop_quotation()?;
    vm.call_quotation(&q)
}

fn w_if(vm: &mut VM) -> Result<(), Error> {
    let q = vm.pop_quotation()?;
    let cond = vm.pop_bool()?;
    if cond {
        vm.call_quotation(&q)?;
    }
    Ok(())
}

fn w_ifelse(vm: &mut VM) -> Result<(), Error> {
    let fq = vm.pop_quotation()?;
    let tq = vm.pop_quotation()?;
    let cond = vm.pop_bool()?;
    if cond {
        vm.call_quotation(&tq)
    } else {
        vm.call_quotation(&fq)
    }
}

// ---- validation reporting ----

fn w_error(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    vm.report_error(msg);
    Ok(())
}

fn w_warn(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    vm.report_warning(msg);
    Ok(())
}

fn w_suggest(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    vm.report_suggestion(msg);
    Ok(())
}

// ---- document-reconciliation helpers ----

fn w_count(vm: &mut VM) -> Result<(), Error> {
    let bundle = vm.pop_bundle()?;
    vm.push(Value::Int(bundle.count() as i64));
    Ok(())
}

fn w_doc_type(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Str(doc.doc_type().to_string()));
    Ok(())
}

fn w_is_canonical(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Bool(doc.is_canonical()));
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn arithmetic_and_stack() {
        let mut vm = VM::new();
        vm.eval("5 3 +").unwrap();
        assert_eq!(vm.pop_int().unwrap(), 8);
        vm.eval("4 dup *").unwrap();
        assert_eq!(vm.pop_int().unwrap(), 16);
    }

    #[test]
    fn quotation_and_control() {
        let mut vm = VM::new();
        vm.eval("5 [ dup * ] call").unwrap();
        assert_eq!(vm.pop_int().unwrap(), 25);
        vm.eval("true [ 42 ] [ 0 ] ifelse").unwrap();
        assert_eq!(vm.pop_int().unwrap(), 42);
    }

    #[test]
    fn validation_reporting() {
        let mut vm = VM::new();
        vm.eval("\"Missing README\" error!").unwrap();
        assert!(!vm.get_validation().success);
        assert_eq!(vm.get_validation().errors.len(), 1);
        vm.eval("\"style nit\" warn!").unwrap();
        assert_eq!(vm.get_validation().warnings.len(), 1);
    }

    #[test]
    fn comparison_and_div_guard() {
        let mut vm = VM::new();
        vm.eval("3 4 <").unwrap();
        assert_eq!(vm.pop_bool().unwrap(), true);
        assert!(vm.eval("1 0 /").is_err());
    }
}
