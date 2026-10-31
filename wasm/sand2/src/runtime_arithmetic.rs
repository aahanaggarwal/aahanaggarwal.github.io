//! Generic Lean integer primitives with borrowed big operands and inlined scalar paths.
//! The representation, arithmetic and ownership contracts match lungo-runtime.
use lungo::__runtime as rt;
use rt::Obj;
use num_integer::Integer;
use num_traits::ToPrimitive;

#[inline]
unsafe fn nat_word(a: Obj) -> Option<u64> { unsafe {
    if a.is_scalar() {Some(rt::lean_unbox(a) as u64)} else {rt::mpz_value(a).to_u64()}
}}
#[inline]
unsafe fn nat_wide(a: Obj) -> Option<u128> { unsafe {
    if a.is_scalar() {Some(rt::lean_unbox(a) as u128)} else {rt::mpz_value(a).to_u128()}
}}
#[inline]
unsafe fn int_wide(a: Obj) -> Option<i128> { unsafe {
    if a.is_scalar() {Some(rt::int::lean_scalar_to_int64(a) as i128)} else {rt::mpz_value(a).to_i128()}
}}
#[inline]
fn nat_result(n: u128) -> Obj {
    if n <= u64::MAX as u128 {rt::nat::lean_uint64_to_nat(n as u64)} else {rt::nat::nat_from_bigint(n.into())}
}
#[inline]
fn int_result(n: i128) -> Obj {
    if let Ok(n) = i64::try_from(n) {rt::int::lean_int64_to_int(n)} else {rt::int::int_from_bigint(n.into())}
}

macro_rules! refs {
    ($a:ident, $b:ident, $convert:path, $left:ident, $right:ident) => {
        let a_value; let b_value;
        let $left = if $a.is_scalar() { a_value = $convert($a); &a_value } else { rt::mpz_value($a) };
        let $right = if $b.is_scalar() { b_value = $convert($b); &b_value } else { rt::mpz_value($b) };
    };
}
#[inline(always)]
unsafe fn retained(a: Obj) -> Obj { unsafe {rt::lean_inc(a);} a }

#[inline(always)]
pub unsafe fn lean_nat_add(a: Obj, b: Obj) -> Obj { unsafe {
    if a == rt::lean_box(0) { return retained(b); }
    if b == rt::lean_box(0) { return retained(a); }
    if a.is_scalar() && b.is_scalar() { return rt::nat::lean_usize_to_nat(rt::lean_unbox(a)+rt::lean_unbox(b)); }
    nat_add_big(a,b)
}}
#[cold] #[inline(never)]
unsafe fn nat_add_big(a: Obj,b: Obj) -> Obj { unsafe {
    if let (Some(x),Some(y)) = (nat_wide(a),nat_wide(b)) {
        if let Some(n) = x.checked_add(y) {return nat_result(n);}
    }
    refs!(a,b,rt::nat::nat_to_bigint,x,y); rt::nat::nat_from_bigint(x+y)
}}
#[inline(always)]
pub unsafe fn lean_nat_sub(a: Obj,b: Obj) -> Obj { unsafe {
    if b == rt::lean_box(0) { return retained(a); }
    if a.is_scalar() && b.is_scalar() { return rt::lean_box(rt::lean_unbox(a).saturating_sub(rt::lean_unbox(b))); }
    nat_sub_big(a,b)
}}
#[cold] #[inline(never)]
unsafe fn nat_sub_big(a: Obj,b: Obj) -> Obj { unsafe {
    if let (Some(x),Some(y)) = (nat_wide(a),nat_wide(b)) { return nat_result(x.saturating_sub(y)); }
    refs!(a,b,rt::nat::nat_to_bigint,x,y);
    if x < y { rt::lean_box(0) } else { rt::nat::nat_from_bigint(x-y) }
}}
#[inline(always)]
pub unsafe fn lean_nat_mul(a: Obj,b: Obj) -> Obj { unsafe {
    if a == rt::lean_box(0) || b == rt::lean_box(0) { return rt::lean_box(0); }
    if a == rt::lean_box(1) { return retained(b); }
    if b == rt::lean_box(1) { return retained(a); }
    if a.is_scalar() && b.is_scalar() {
        if let Some(n) = rt::lean_unbox(a).checked_mul(rt::lean_unbox(b)) {
            if n <= rt::LEAN_MAX_SMALL_NAT { return rt::lean_box(n); }
        }
    }
    nat_mul_big(a,b)
}}
#[cold] #[inline(never)]
unsafe fn nat_mul_big(a: Obj,b: Obj) -> Obj { unsafe {
    if let (Some(x),Some(y)) = (nat_wide(a),nat_wide(b)) {
        if let Some(n) = x.checked_mul(y) {return nat_result(n);}
    }
    refs!(a,b,rt::nat::nat_to_bigint,x,y); rt::nat::nat_from_bigint(x*y)
}}
#[inline(always)]
pub unsafe fn lean_nat_div(a: Obj,b: Obj) -> Obj { unsafe {
    if b == rt::lean_box(0) { return rt::lean_box(0); }
    if b == rt::lean_box(1) { return retained(a); }
    if a.is_scalar() && b.is_scalar() { return rt::lean_box(rt::lean_unbox(a)/rt::lean_unbox(b)); }
    nat_div_big(a,b)
}}
#[cold] #[inline(never)]
unsafe fn nat_div_big(a: Obj,b: Obj) -> Obj { unsafe {
    if let (Some(x),Some(y)) = (nat_word(a),nat_word(b)) { return rt::nat::lean_uint64_to_nat(x/y); }
    if let (Some(x),Some(y)) = (nat_wide(a),nat_wide(b)) { return nat_result(x/y); }
    refs!(a,b,rt::nat::nat_to_bigint,x,y); rt::nat::nat_from_bigint(x/y)
}}
#[inline(always)]
pub unsafe fn lean_nat_mod(a: Obj,b: Obj) -> Obj { unsafe {
    if b == rt::lean_box(0) { return retained(a); }
    if a.is_scalar() && b.is_scalar() { return rt::lean_box(rt::lean_unbox(a)%rt::lean_unbox(b)); }
    nat_mod_big(a,b)
}}
#[cold] #[inline(never)]
unsafe fn nat_mod_big(a: Obj,b: Obj) -> Obj { unsafe {
    if let (Some(x),Some(y)) = (nat_word(a),nat_word(b)) { return rt::nat::lean_uint64_to_nat(x%y); }
    if let (Some(x),Some(y)) = (nat_wide(a),nat_wide(b)) { return nat_result(x%y); }
    refs!(a,b,rt::nat::nat_to_bigint,x,y); rt::nat::nat_from_bigint(x%y)
}}
macro_rules! nat_cmp {
    ($name:ident,$op:tt) => {
        #[inline(always)] pub unsafe fn $name(a: Obj,b: Obj) -> u8 { unsafe {
            if a.is_scalar() && b.is_scalar() { return (rt::lean_unbox(a) $op rt::lean_unbox(b)) as u8; }
            refs!(a,b,rt::nat::nat_to_bigint,x,y); (x $op y) as u8
        }}
    }
}
nat_cmp!(lean_nat_dec_lt,<);
nat_cmp!(lean_nat_dec_le,<=);

macro_rules! int_binary {
    ($name:ident,$slow:ident,$op:tt,$checked:ident) => {
        #[inline(always)] pub unsafe fn $name(a: Obj,b: Obj) -> Obj { unsafe {
            if stringify!($op) == "*" {
                if a == rt::lean_box(0) || b == rt::lean_box(0) { return rt::lean_box(0); }
                if a == rt::lean_box(1) { return retained(b); }
                if b == rt::lean_box(1) { return retained(a); }
            } else {
                if b == rt::lean_box(0) { return retained(a); }
                if stringify!($op) == "+" && a == rt::lean_box(0) { return retained(b); }
            }
            if a.is_scalar() && b.is_scalar() {
                if let Some(n) = rt::int::lean_scalar_to_int64(a).$checked(rt::int::lean_scalar_to_int64(b)) {
                    return rt::int::lean_int64_to_int(n);
                }
            }
            $slow(a,b)
        }}
        #[cold] #[inline(never)] unsafe fn $slow(a: Obj,b: Obj) -> Obj { unsafe {
            if let (Some(x),Some(y)) = (int_wide(a),int_wide(b)) {
                if let Some(n) = x.$checked(y) { return int_result(n); }
            }
            refs!(a,b,rt::int::int_to_bigint,x,y); rt::int::int_from_bigint(x $op y)
        }}
    }
}
int_binary!(lean_int_add,int_add_big,+,checked_add);
int_binary!(lean_int_sub,int_sub_big,-,checked_sub);
int_binary!(lean_int_mul,int_mul_big,*,checked_mul);
#[inline(always)]
pub unsafe fn lean_int_ediv(a: Obj,b: Obj) -> Obj { unsafe {
    if b == rt::lean_box(0) { return rt::lean_box(0); }
    if b == rt::lean_box(1) { return retained(a); }
    if a.is_scalar() && b.is_scalar() { return rt::intrinsics::lean_int_ediv(a,b); }
    int_ediv_big(a,b)
}}
#[cold] #[inline(never)]
unsafe fn int_ediv_big(a: Obj,b: Obj) -> Obj { unsafe {
    if let (Some(x),Some(y)) = (int_wide(a),int_wide(b)) {
        if let Some(n) = x.checked_div_euclid(y) {return int_result(n);}
    }
    refs!(a,b,rt::int::int_to_bigint,x,y);
    let (q,r) = x.div_rem(y);
    let zero = rt::int::int_to_bigint(rt::lean_box(0));
    let q = if r < zero { if y > &zero {q-1} else {q+1} } else {q};
    rt::int::int_from_bigint(q)
}}
macro_rules! int_cmp {
    ($name:ident,$op:tt) => {
        #[inline(always)] pub unsafe fn $name(a: Obj,b: Obj) -> u8 { unsafe {
            if a.is_scalar() && b.is_scalar() { return (rt::int::lean_scalar_to_int64(a) $op rt::int::lean_scalar_to_int64(b)) as u8; }
            refs!(a,b,rt::int::int_to_bigint,x,y); (x $op y) as u8
        }}
    }
}
int_cmp!(lean_int_dec_lt,<);
int_cmp!(lean_int_dec_le,<=);

#[cfg(any(test,target_arch="wasm32"))]
pub fn self_test() -> bool {
    unsafe {
        let cases = ["0","1","2","31","1073741823","1073741824","2147483647","2147483648",
            "4294967295","9223372036854775807","18446744073709551615","170141183460469231731687303715884105727","170141183460469231731687303715884105728","340282366920938463463374607431768211455","10000000000000000000000000000000000000000"];
        let nat_ops: [(unsafe fn(Obj,Obj)->Obj,unsafe fn(Obj,Obj)->Obj);5] = [
            (lean_nat_add,rt::intrinsics::lean_nat_add),(lean_nat_sub,rt::intrinsics::lean_nat_sub),
            (lean_nat_mul,rt::intrinsics::lean_nat_mul),(lean_nat_div,rt::intrinsics::lean_nat_div),
            (lean_nat_mod,rt::intrinsics::lean_nat_mod)];
        for left in cases { for right in cases {
            let a=rt::nat::lean_cstr_to_nat(left);let b=rt::nat::lean_cstr_to_nat(right);
            for (fast,reference) in nat_ops {
                let actual=fast(a,b);let expected=reference(a,b);
                let same=rt::nat::nat_to_bigint(actual)==rt::nat::nat_to_bigint(expected);
                rt::lean_dec(actual);rt::lean_dec(expected); if !same {return false;}
            }
            if lean_nat_dec_lt(a,b)!=rt::intrinsics::lean_nat_dec_lt(a,b) || lean_nat_dec_le(a,b)!=rt::intrinsics::lean_nat_dec_le(a,b) {return false;}
            rt::lean_dec(a);rt::lean_dec(b);
        }}
        let mut signed:Vec<String>=cases.iter().map(|s|s.to_string()).collect();
        signed.extend(cases.iter().filter(|s|**s!="0").map(|s|format!("-{s}")));
        let int_ops: [(unsafe fn(Obj,Obj)->Obj,unsafe fn(Obj,Obj)->Obj);4] = [
            (lean_int_add,rt::intrinsics::lean_int_add),(lean_int_sub,rt::intrinsics::lean_int_sub),
            (lean_int_mul,rt::intrinsics::lean_int_mul),(lean_int_ediv,rt::intrinsics::lean_int_ediv)];
        for left in &signed {for right in &signed {
            let a=rt::int::lean_cstr_to_int(left);let b=rt::int::lean_cstr_to_int(right);
            for (fast,reference) in int_ops {
                let actual=fast(a,b);let expected=reference(a,b);
                let same=rt::int::int_to_bigint(actual)==rt::int::int_to_bigint(expected);
                rt::lean_dec(actual);rt::lean_dec(expected);if !same {return false;}
            }
            if lean_int_dec_lt(a,b)!=rt::intrinsics::lean_int_dec_lt(a,b) || lean_int_dec_le(a,b)!=rt::intrinsics::lean_int_dec_le(a,b) {return false;}
            rt::lean_dec(a);rt::lean_dec(b);
        }}
    }
    true
}
