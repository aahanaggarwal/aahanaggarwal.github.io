//! Browser ABI and retained Lean state handles. Physics, initialization, edits,
//! catalogue, scene definitions and rendering are generated from Lean.
pub mod physics {
    lungo::include_lean!("sand2");
}

pub struct Universe {
    state: Option<physics::Simulation>,
    history: Vec<physics::Simulation>,
    pixels: Vec<u8>,
    #[cfg(target_arch = "wasm32")]
    text: Vec<u8>,
}
impl Universe {
    pub fn new(width: u32, height: u32) -> Self {
        Self { state: Some(physics::new_simulation(width, height)), history: Vec::new(), pixels: Vec::new(), #[cfg(target_arch = "wasm32")] text: Vec::new() }
    }
    fn update(&mut self, action: impl FnOnce(physics::Simulation) -> physics::Simulation) {
        self.state = Some(action(self.state.take().expect("initialized Lean world")));
    }
    fn state(&self) -> physics::Simulation { self.state.as_ref().expect("initialized Lean world").clone() }
    pub fn tick(&mut self) { self.update(physics::tick_simulation); }
    pub fn clear(&mut self) { self.update(physics::clear_simulation); }
    pub fn scene(&mut self, scene: u32) { self.update(|s| physics::scene_simulation(s, scene)); }
    pub fn paint(&mut self, x: i32, y: i32, radius: u32, material: u32) {
        self.update(|s| physics::paint_simulation(s, x, y, radius, material));
    }
    pub fn checkpoint(&mut self) -> u32 {
        self.history.push(self.state());
        if self.history.len() > 16 { self.history.remove(0); }
        self.history.len() as u32
    }
    pub fn undo(&mut self) -> u32 {
        if let Some(state) = self.history.pop() { self.state = Some(state); }
        self.history.len() as u32
    }
    pub fn render(&mut self, view: u32) -> u32 {
        self.pixels = physics::render_simulation(self.state(), view).0;
        physics::count_simulation(self.state())
    }
    pub fn digest(&self) -> u64 { physics::digest_simulation(self.state()) }
    pub fn audit(&self) -> String { physics::audit_simulation(self.state()) }
    #[cfg(target_arch = "wasm32")]
    fn text(&mut self, value: String) -> u32 { self.text = value.into_bytes(); self.text.as_ptr() as u32 }
}

// C ABI uses buffers owned here; JavaScript obtains a fresh view after calls
// because the Wasm linear memory can grow. No raw simulation state is exposed.
#[cfg(target_arch = "wasm32")]
mod browser {
    use super::{Universe, physics};
    use std::cell::RefCell;
    thread_local! { static WORLD: RefCell<Option<Universe>> = const { RefCell::new(None) }; }
    fn world<R: Default>(f: impl FnOnce(&mut Universe) -> R) -> R {
        WORLD.with(|slot| slot.borrow_mut().as_mut().map(f).unwrap_or_default())
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_new(width: u32, height: u32) { WORLD.with(|slot| *slot.borrow_mut() = Some(Universe::new(width, height))); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_free() { WORLD.with(|slot| *slot.borrow_mut() = None); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_tick() { world(|w| w.tick()); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_clear() { world(|w| w.clear()); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_scene(scene: u32) { world(|w| w.scene(scene)); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_paint(x: i32, y: i32, radius: u32, material: u32) { world(|w| w.paint(x, y, radius, material)); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_render(view: u32) -> u32 { world(|w| w.render(view)) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_pixels() -> u32 { world(|w| w.pixels.as_ptr() as u32) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_checkpoint() -> u32 { world(|w| w.checkpoint()) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_undo() -> u32 { world(|w| w.undo()) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_digest() -> u64 { world(|w| w.digest()) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_audit() -> u32 { world(|w| w.text(w.audit())) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_catalogue() -> u32 { world(|w| w.text(physics::catalogue())) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_inspect(x: u32, y: u32) -> u32 { world(|w| w.text(physics::inspect_simulation(w.state(), x, y))) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_oracle(scene: u32, ticks: u32) -> u32 { world(|w| w.text(physics::oracle(scene, ticks))) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_text_length() -> u32 { world(|w| w.text.len() as u32) }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn complete_timesteps_conserve_all_elements_and_total_energy() {
        for scene in 1..=8 {
            let mut w = Universe::new(24, 20); w.scene(scene);
            let before = w.audit();
            for tick in 0..12 { w.tick(); assert_eq!(w.audit(), before, "scene {scene}, tick {tick}"); }
        }
    }
    #[test]
    fn checkpoint_restores_every_state_component() {
        let mut w = Universe::new(24, 20); w.scene(3);
        for _ in 0..3 { w.tick(); }
        let before = w.digest(); let budget = w.audit();
        w.checkpoint(); w.paint(12, 5, 3, 9); for _ in 0..3 { w.tick(); }
        assert_ne!(w.digest(), before); w.undo();
        assert_eq!(w.digest(), before); assert_eq!(w.audit(), budget);
    }
    #[test]
    fn render_and_inspection_are_read_only() {
        let mut w = Universe::new(24, 20); w.scene(2);
        let before = w.digest();
        for view in 0..3 { w.render(view); assert_eq!(w.pixels.len(), 24*20*4); }
        physics::inspect_simulation(w.state(), 0, 0);
        assert_eq!(w.digest(), before);
    }
    #[test]
    fn external_edits_do_not_break_the_closed_vessel() {
        let mut w = Universe::new(24, 20);
        w.paint(i32::MIN, i32::MAX, u32::MAX, u32::MAX);
        w.paint(0, 0, 16, 0);
        for x in 0..24 { assert!(physics::inspect_simulation(w.state(), x, 0).starts_with("Iron")); }
    }
}
