//! Grid storage, disjoint block scheduling, and pixels. All movement and
//! chemistry come from Sand2.lean via Lungo; no parallel Rust physics rules.
pub mod physics {
    lungo::include_lean!("sand2");
}

const COLORS: [[u8; 3]; 14] = [
    [12, 17, 17], [230, 188, 119], [47, 129, 207], [111, 122, 126],
    [145, 94, 58], [255, 155, 48], [176, 211, 213], [128, 102, 58],
    [184, 228, 74], [255, 91, 39], [83, 171, 107], [137, 213, 235],
    [94, 103, 108], [146, 179, 176],
];

pub struct Universe {
    width: usize,
    height: usize,
    cells: Vec<u8>,
    pixels: Vec<u8>,
    frame: u32,
    random: u32,
}

impl Universe {
    pub fn new(width: usize, height: usize) -> Self {
        let width = width.clamp(16, 512) & !1;
        let height = height.clamp(16, 512) & !1;
        let mut world = Self {
            width, height, cells: vec![0; width * height],
            pixels: vec![0; width * height * 4], frame: 0, random: 0x5a17_2026,
        };
        world.repair();
        world
    }

    pub fn clear(&mut self) {
        self.cells.fill(0);
        self.frame = 0;
        self.random = 0x5a17_2026;
        self.repair();
    }

    pub fn repair(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                let i = y * self.width + x;
                if x == 0 || y == 0 || x == self.width - 1 || y == self.height - 1 {
                    self.cells[i] = 3;
                } else if self.cells[i] >= COLORS.len() as u8 {
                    self.cells[i] = 0;
                }
            }
        }
    }

    pub fn tick(&mut self) {
        // Two shifted Margolus partitions. Every cell occurs in at most one
        // block in a substep, so writes never compete and no wraparound occurs.
        for phase in 0..2 {
            for y in (phase..self.height - 1).step_by(2) {
                for x in (phase..self.width - 1).step_by(2) {
                    let i = y * self.width + x;
                    let j = i + self.width;
                    let block = u32::from_le_bytes([
                        self.cells[i], self.cells[i + 1], self.cells[j], self.cells[j + 1],
                    ]);
                    if block == 0 { continue; }
                    self.random ^= self.random << 13;
                    self.random ^= self.random >> 17;
                    self.random ^= self.random << 5;
                    let result = physics::step_block(block, self.random).to_le_bytes();
                    self.cells[i] = result[0]; self.cells[i + 1] = result[1];
                    self.cells[j] = result[2]; self.cells[j + 1] = result[3];
                }
            }
        }
        self.frame = self.frame.wrapping_add(1);
    }

    pub fn paint(&mut self, cx: i32, cy: i32, radius: i32, material: u8) {
        if material >= COLORS.len() as u8 { return; }
        let radius = radius.clamp(1, 24);
        let left = cx.saturating_sub(radius).max(1);
        let right = cx.saturating_add(radius).min(self.width as i32 - 2);
        let top = cy.saturating_sub(radius).max(1);
        let bottom = cy.saturating_add(radius).min(self.height as i32 - 2);
        for y in top..=bottom {
            for x in left..=right {
                let dx = x - cx;
                let dy = y - cy;
                if dx * dx + dy * dy <= radius * radius {
                    let i = y as usize * self.width + x as usize;
                    // Mobile particles fill space; solid tools and the eraser
                    // can edit existing structures. This is a painting policy.
                    if material == 0 || matches!(material, 3 | 4 | 10 | 11 | 13) || self.cells[i] == 0 {
                        self.cells[i] = material;
                    }
                }
            }
        }
    }

    pub fn render(&mut self) -> u32 {
        let mut count = 0;
        for (i, &material) in self.cells.iter().enumerate() {
            let x = i % self.width;
            let y = i / self.width;
            let edge = x == 0 || y == 0 || x == self.width - 1 || y == self.height - 1;
            let base = if edge { [29, 38, 36] } else { COLORS[material as usize] };
            let motion = if matches!(material, 5 | 6 | 9 | 12) { self.frame / 3 } else { 0 };
            let hash = (i as u32).wrapping_mul(747_796_405).wrapping_add(motion.wrapping_mul(2_891_336_453));
            let grain = if material == 0 || edge { 0 } else { ((hash >> 24) % 19) as i16 - 9 };
            for (channel, value) in base.iter().enumerate() {
                self.pixels[i * 4 + channel] = (i16::from(*value) + grain).clamp(0, 255) as u8;
            }
            self.pixels[i * 4 + 3] = 255;
            if material != 0 && !edge { count += 1; }
        }
        count
    }
}

// A small C ABI keeps the browser adapter independent of a binding generator.
// WASI is Lungo's supported WebAssembly target. The adapter grants no file,
// socket or process access; the simulation has no such requirements.
#[cfg(target_arch = "wasm32")]
mod browser {
    use super::Universe;
    use std::cell::RefCell;
    thread_local! { static WORLD: RefCell<Option<Universe>> = const { RefCell::new(None) }; }
    fn world<R: Default>(f: impl FnOnce(&mut Universe) -> R) -> R {
        WORLD.with(|slot| slot.borrow_mut().as_mut().map(f).unwrap_or_default())
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_new(width: u32, height: u32) {
        WORLD.with(|slot| *slot.borrow_mut() = Some(Universe::new(width as usize, height as usize)));
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_free() { WORLD.with(|slot| *slot.borrow_mut() = None); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_tick() { world(|w| w.tick()); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_clear() { world(|w| w.clear()); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_repair() { world(|w| w.repair()); }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_paint(x: i32, y: i32, radius: i32, material: u32) {
        if material < 14 { world(|w| w.paint(x, y, radius, material as u8)); }
    }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_render() -> u32 { world(|w| w.render()) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_pixels() -> u32 { world(|w| w.pixels.as_ptr() as u32) }
    #[unsafe(no_mangle)]
    pub extern "C" fn world_cells() -> u32 { world(|w| w.cells.as_ptr() as u32) }
    #[unsafe(no_mangle)]
    pub extern "C" fn physics_probe(block: u32, noise: u32) -> u32 { super::physics::step_block(block, noise) }
}

#[cfg(test)]
mod tests {
    use super::*;
    fn count(w: &Universe, material: u8) -> usize { w.cells.iter().filter(|&&m| m == material).count() }

    #[test]
    fn generated_settling_conserves_every_pair() {
        for a in 0..14 { for b in 0..14 {
            let result = physics::settle(a, b).to_le_bytes();
            assert!(result[..2] == [a as u8, b as u8] || result[..2] == [b as u8, a as u8]);
        }}
    }
    #[test]
    fn generated_blocks_keep_valid_materials() {
        for block in 0_u32..38_416 {
            let mut n = block;
            let mut input = [0_u8; 4];
            for m in &mut input { *m = (n % 14) as u8; n /= 14; }
            for noise in [0, 1, 127, 0xa671_08d3, u32::MAX] {
                assert!(physics::step_block(u32::from_le_bytes(input), noise).to_le_bytes().iter().all(|&m| m < 14));
            }
        }
    }
    #[test]
    fn sand_falls_and_is_conserved() {
        let mut w = Universe::new(48, 48);
        w.paint(24, 8, 4, 1);
        let grains = count(&w, 1);
        for _ in 0..100 { w.tick(); }
        assert_eq!(count(&w, 1), grains);
        assert!(w.cells[..24 * w.width].iter().all(|&m| m != 1));
    }
    #[test]
    fn joined_walls_block_diagonal_tunneling() {
        for noise in 0..128 {
            for input in [[1, 13, 13, 0], [13, 1, 0, 13], [2, 3, 3, 0]] {
                assert_eq!(physics::step_block(u32::from_le_bytes(input), noise).to_le_bytes(), input);
            }
        }
    }
    #[test]
    fn lava_and_water_react_in_generated_core() {
        let result = physics::step_block(u32::from_le_bytes([9, 0, 2, 0]), 0x1234_5678).to_le_bytes();
        assert!(result.contains(&3));
        assert!(result.contains(&6));
        assert!(!result.contains(&9));
    }
    #[test]
    fn walls_survive_paint_and_simulation() {
        let mut w = Universe::new(32, 32);
        w.paint(-3, 0, 24, 0);
        w.paint(32, 32, 24, 8);
        for _ in 0..40 { w.tick(); }
        for y in 0..32 { for x in 0..32 {
            if x == 0 || y == 0 || x == 31 || y == 31 { assert_eq!(w.cells[y * 32 + x], 3); }
        }}
    }
    #[test]
    fn identical_worlds_produce_identical_results() {
        let mut a = Universe::new(64, 48);
        let mut b = Universe::new(64, 48);
        for w in [&mut a, &mut b] {
            w.paint(24, 10, 8, 2); w.paint(30, 8, 5, 1);
            for _ in 0..100 { w.tick(); }
        }
        assert_eq!(a.cells, b.cells);
    }
    #[test]
    fn fixed_materials_do_not_move_without_chemistry() {
        for mat in [3, 4, 10, 11, 13] {
            let mut w = Universe::new(32, 32);
            w.paint(16, 12, 2, mat);
            let before = w.cells.clone();
            for _ in 0..10 { w.tick(); }
            assert_eq!(w.cells, before);
        }
    }
    #[test]
    fn clear_and_repair_validate_the_grid() {
        let mut w = Universe::new(16, 16);
        w.cells[20] = 255;
        w.repair();
        assert_eq!(w.cells[20], 0);
        w.paint(i32::MAX, i32::MIN, 24, 1);
        w.paint(8, 8, 4, 255);
        w.paint(8, 8, 4, 1);
        assert!(w.render() > 0);
        w.clear();
        assert_eq!(w.render(), 0);
    }
}
