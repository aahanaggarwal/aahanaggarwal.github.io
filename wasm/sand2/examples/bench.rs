use sand2::Universe;
fn main() {
    for (width, height) in [(24,20),(64,40),(96,64)] {
        for scene in [0,1,2,3,4] {
            let mut w = Universe::new(width,height); w.scene(scene);
            let start = std::time::Instant::now();
            for _ in 0..5 { w.tick(); }
            println!("{width}x{height} scene {scene}: {:.2} ms/tick",start.elapsed().as_secs_f64()*200.0);
        }
    }
}
