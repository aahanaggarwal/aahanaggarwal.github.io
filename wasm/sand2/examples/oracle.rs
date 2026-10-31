//! Compare generated native Rust with reference vectors computed by Lean.
use std::io::{self, BufRead};
fn main() {
    let mut count = 0;
    for line in io::stdin().lock().lines() {
        let line = line.expect("read oracle vector");
        let values: Vec<u32> = line.split(',').map(|v| v.parse().expect("oracle integer")).collect();
        assert_eq!(values.len(), 3);
        assert_eq!(sand2::physics::step_block(values[0], values[1]), values[2], "Lean/native Rust mismatch for {line}");
        count += 1;
    }
    assert!(count >= 2200, "oracle vectors missing");
    println!("Lean/native Rust differential check: {count} vectors agree");
}
