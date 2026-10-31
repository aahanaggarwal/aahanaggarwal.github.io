use sand2::Universe;
use std::time::Instant;
fn main() {
    let args: Vec<String> = std::env::args().collect();
    let number = |i: usize, default: u32| args.get(i).and_then(|x| x.parse::<u32>().ok()).unwrap_or(default);
    let width=number(1,24); let height=number(2,20); let scene=number(3,1); let warm=number(4,1);
    let mut world=Universe::new(width,height); world.scene(scene);
    for _ in 0..warm { world.tick(); }
    for (stage,label) in [(0,"geometry"),(1,"viscosity x"),(2,"viscosity y"),(3,"pressure and viscosity"),(7,"pressure iteration count"),(4,"one candidate"),(5,"thermochemistry"),(6,"complete fluid step")] {
        let start=Instant::now();
        let digest=world.numerical_probe(stage);
        eprintln!("{width}x{height} {label}: {:.2} ms, digest={digest}",start.elapsed().as_secs_f64()*1000.0);
    }
    eprintln!("Rejected minimum steps: {}",world.solver_failures());
}
