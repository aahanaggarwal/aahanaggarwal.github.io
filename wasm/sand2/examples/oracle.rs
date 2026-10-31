use std::io::{self, BufRead};
fn main() {
    let mut n = 0;
    for line in io::stdin().lock().lines() {
        let line = line.unwrap();
        let mut columns = line.splitn(3, ';');
        let scene: u32 = columns.next().unwrap().parse().unwrap();
        let ticks: u32 = columns.next().unwrap().parse().unwrap();
        let expected = columns.next().unwrap();
        assert_eq!(sand2::physics::oracle(scene, ticks), expected, "scene {scene}, ticks {ticks}");
        n += 1;
    }
    println!("Lean/native Rust differential check: {n} complete-world states agree.");
}
