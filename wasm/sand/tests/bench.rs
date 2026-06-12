use sand::Universe;
use std::time::Instant;

#[test]
fn bench_full_grid() {
    let mut u = Universe::new(256, 256);
    // fill half the grid with mixed materials
    for x in 0..256 {
        for y in 128..256 {
            let m = match (x + y) % 5 { 0 => 1, 1 => 2, 2 => 7, 3 => 15, _ => 3 };
            u.paint(y, x, m, 0);
        }
    }
    let t = Instant::now();
    for _ in 0..600 {
        u.tick();
        u.render();
    }
    let per = t.elapsed().as_secs_f64() * 1000.0 / 600.0;
    println!("avg tick+render: {:.3} ms", per);
    assert!(per < 16.0, "too slow: {:.3} ms/frame", per);
}
