use wasm_bindgen::prelude::*;

// === Materials ===
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Mat {
    Empty = 0,
    Sand = 1,
    Water = 2,
    Stone = 3,
    Wood = 4,
    Fire = 5,
    Steam = 6,
    Oil = 7,
    Acid = 8,
    Lava = 9,
    Plant = 10,
    Ice = 11,
    Smoke = 12,
    Glass = 13,
    Obsidian = 14,
    Gunpowder = 15,
    Salt = 16,
    SaltWater = 17,
    Ember = 18,
    Ash = 19,
    Metal = 20,
}

const MAT_COUNT: u8 = 21;

impl Mat {
    fn from_u8(v: u8) -> Mat {
        if v >= MAT_COUNT {
            return Mat::Empty;
        }
        unsafe { std::mem::transmute(v) }
    }

    fn is_powder(&self) -> bool {
        matches!(self, Mat::Sand | Mat::Gunpowder | Mat::Salt | Mat::Ash)
    }

    fn is_liquid(&self) -> bool {
        matches!(self, Mat::Water | Mat::Oil | Mat::Acid | Mat::Lava | Mat::SaltWater)
    }

    fn is_gas(&self) -> bool {
        matches!(self, Mat::Fire | Mat::Steam | Mat::Smoke)
    }

    fn is_static(&self) -> bool {
        matches!(
            self,
            Mat::Stone
                | Mat::Wood
                | Mat::Plant
                | Mat::Ice
                | Mat::Glass
                | Mat::Obsidian
                | Mat::Ember
                | Mat::Metal
        )
    }

    fn is_solid(&self) -> bool {
        self.is_powder() || self.is_static()
    }

    // Relative density: heavier sinks below lighter. Empty = 0.
    fn density(&self) -> i8 {
        match self {
            Mat::Stone | Mat::Obsidian | Mat::Metal => 100,
            Mat::Glass => 60,
            Mat::Sand => 55,
            Mat::Salt => 52,
            Mat::Gunpowder => 48,
            Mat::Lava => 45,
            Mat::SaltWater => 32,
            Mat::Water | Mat::Acid => 30,
            Mat::Ice => 25,
            Mat::Wood | Mat::Plant | Mat::Ember => 20,
            Mat::Ash => 15,
            Mat::Oil => 10,
            Mat::Fire | Mat::Steam | Mat::Smoke => -10,
            Mat::Empty => 0,
        }
    }

    fn base_temperature(&self) -> f32 {
        match self {
            Mat::Fire => 650.0,
            Mat::Ember => 600.0,
            Mat::Lava => 1100.0,
            Mat::Ice => -25.0,
            Mat::Steam => 160.0,
            Mat::Smoke => 120.0,
            _ => 20.0,
        }
    }

    // Heat conduction factor (0..1): how fast this cell equalizes with neighbors.
    fn conductivity(&self) -> f32 {
        match self {
            Mat::Metal => 0.45,
            Mat::Water | Mat::SaltWater | Mat::Acid => 0.18,
            Mat::Lava => 0.10,
            // steam barely exchanges heat in bulk, so it can rise a long
            // way before condensing instead of raining out immediately
            Mat::Steam => 0.03,
            Mat::Smoke | Mat::Fire => 0.20,
            Mat::Sand | Mat::Salt | Mat::Ash | Mat::Gunpowder => 0.08,
            Mat::Stone | Mat::Obsidian | Mat::Glass => 0.05,
            Mat::Ice => 0.12,
            Mat::Wood | Mat::Plant | Mat::Ember => 0.06,
            Mat::Oil => 0.10,
            Mat::Empty => 0.12,
        }
    }

    // Ignition temperature, or None if not flammable.
    fn ignition_temp(&self) -> Option<f32> {
        match self {
            Mat::Wood => Some(280.0),
            Mat::Plant => Some(200.0),
            Mat::Oil => Some(230.0),
            Mat::Gunpowder => Some(170.0),
            _ => None,
        }
    }

    fn base_color(&self) -> [u8; 3] {
        match self {
            Mat::Empty => [10, 10, 10],
            Mat::Sand => [225, 191, 138],
            Mat::Water => [24, 96, 175],
            Mat::Stone => [118, 118, 118],
            Mat::Wood => [102, 70, 40],
            Mat::Fire => [255, 140, 25],
            Mat::Steam => [185, 190, 200],
            Mat::Oil => [58, 48, 38],
            Mat::Acid => [130, 230, 40],
            Mat::Lava => [215, 75, 18],
            Mat::Plant => [42, 160, 52],
            Mat::Ice => [160, 205, 240],
            Mat::Smoke => [58, 58, 58],
            Mat::Glass => [175, 205, 215],
            Mat::Obsidian => [48, 22, 72],
            Mat::Gunpowder => [78, 78, 88],
            Mat::Salt => [232, 232, 230],
            Mat::SaltWater => [38, 115, 155],
            Mat::Ember => [185, 70, 22],
            Mat::Ash => [108, 104, 98],
            Mat::Metal => [138, 144, 155],
        }
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum MoveResult {
    Moved,
    Blocked,
    NoStep,
}

const GRAVITY: f32 = 0.18;
const MAX_FALL: f32 = 4.0;
const AMBIENT: f32 = 20.0;

#[wasm_bindgen]
pub struct Universe {
    width: i32,
    height: i32,
    mat: Vec<u8>,
    vx: Vec<f32>,
    vy: Vec<f32>,
    temp: Vec<f32>,
    temp_back: Vec<f32>,
    life: Vec<u8>,
    variant: Vec<u8>,
    updated: Vec<u8>, // generation stamp of last move
    pixels: Vec<u8>,  // RGBA output
    gen: u8,
    rng: u32,
    heat_view: bool,
}

#[wasm_bindgen]
impl Universe {
    pub fn new(width: u32, height: u32) -> Universe {
        let n = (width * height) as usize;
        Universe {
            width: width as i32,
            height: height as i32,
            mat: vec![0; n],
            vx: vec![0.0; n],
            vy: vec![0.0; n],
            temp: vec![AMBIENT; n],
            temp_back: vec![AMBIENT; n],
            life: vec![0; n],
            variant: vec![0; n],
            updated: vec![0; n],
            pixels: vec![0; n * 4],
            gen: 0,
            rng: 0xB45BE,
            heat_view: false,
        }
    }

    pub fn width(&self) -> u32 {
        self.width as u32
    }
    pub fn height(&self) -> u32 {
        self.height as u32
    }
    pub fn pixels(&self) -> *const u8 {
        self.pixels.as_ptr()
    }
    pub fn set_heat_view(&mut self, on: bool) {
        self.heat_view = on;
    }
    pub fn mat_at(&self, x: i32, y: i32) -> u8 {
        if self.in_bounds(x, y) {
            self.mat[self.idx(x, y)]
        } else {
            0
        }
    }

    pub fn clear(&mut self) {
        self.mat.fill(0);
        self.vx.fill(0.0);
        self.vy.fill(0.0);
        self.temp.fill(AMBIENT);
        self.temp_back.fill(AMBIENT);
        self.life.fill(0);
        self.updated.fill(0);
    }

    pub fn paint(&mut self, row: i32, col: i32, mat_val: u8, radius: i32) {
        let m = Mat::from_u8(mat_val);
        let r2 = radius * radius;
        for dr in -radius..=radius {
            for dc in -radius..=radius {
                if dr * dr + dc * dc > r2 {
                    continue;
                }
                let y = row + dr;
                let x = col + dc;
                if !self.in_bounds(x, y) {
                    continue;
                }
                // Sparse spray for powders/liquids feels much nicer with big brushes
                if radius > 2 && m != Mat::Empty && !m.is_static() && (self.rand() & 3) == 0 {
                    continue;
                }
                let i = self.idx(x, y);
                // Don't paint over existing cells (except eraser / static building)
                if m != Mat::Empty && !m.is_static() && self.mat[i] != 0 {
                    continue;
                }
                self.place(i, m);
            }
        }
    }

    pub fn tick(&mut self) {
        self.gen = self.gen.wrapping_add(1);
        self.diffuse_heat();

        let ltr = self.gen & 1 == 0;
        // Bottom-up scan: falling things see free space below before it's claimed;
        // gases rising are stamped so they're not re-updated this tick.
        for y in (0..self.height).rev() {
            if ltr {
                for x in 0..self.width {
                    self.update_cell(x, y);
                }
            } else {
                for x in (0..self.width).rev() {
                    self.update_cell(x, y);
                }
            }
        }
    }

    pub fn render(&mut self) {
        let n = (self.width * self.height) as usize;
        for i in 0..n {
            let m = Mat::from_u8(self.mat[i]);
            let t = self.temp[i];

            let (r, g, b) = if self.heat_view {
                heat_color(t)
            } else {
                let [mut r, mut g, mut b] = m.base_color();
                if m != Mat::Empty {
                    // per-grain shade jitter
                    let v = self.variant[i] as i32 - 8;
                    r = (r as i32 + v).clamp(0, 255) as u8;
                    g = (g as i32 + v).clamp(0, 255) as u8;
                    b = (b as i32 + v).clamp(0, 255) as u8;
                    // fire/ember flicker
                    if matches!(m, Mat::Fire | Mat::Ember) {
                        let f = (self.rand() & 31) as i32 - 16;
                        r = (r as i32 + f).clamp(0, 255) as u8;
                        g = (g as i32 + f / 2).clamp(0, 255) as u8;
                    }
                }
                // incandescent glow for anything hot
                if t > 300.0 {
                    let glow = ((t - 300.0) / 800.0).min(1.0);
                    r = lerp_u8(r, 255, glow * 0.85);
                    g = lerp_u8(g, 150, glow * 0.7);
                    b = lerp_u8(b, 40, glow * 0.5);
                    if t > 1000.0 {
                        let w = ((t - 1000.0) / 600.0).min(1.0) * 0.6;
                        r = lerp_u8(r, 255, w);
                        g = lerp_u8(g, 255, w);
                        b = lerp_u8(b, 230, w);
                    }
                }
                (r, g, b)
            };

            let p = i * 4;
            self.pixels[p] = r;
            self.pixels[p + 1] = g;
            self.pixels[p + 2] = b;
            self.pixels[p + 3] = 255;
        }
    }
}

// === Internals ===
impl Universe {
    #[inline]
    fn idx(&self, x: i32, y: i32) -> usize {
        (y * self.width + x) as usize
    }

    #[inline]
    fn in_bounds(&self, x: i32, y: i32) -> bool {
        x >= 0 && x < self.width && y >= 0 && y < self.height
    }

    fn rand(&mut self) -> u32 {
        let mut x = self.rng;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.rng = x;
        x
    }

    fn frand(&mut self) -> f32 {
        (self.rand() & 0xFFFF) as f32 / 65535.0
    }

    fn place(&mut self, i: usize, m: Mat) {
        self.mat[i] = m as u8;
        self.vx[i] = 0.0;
        self.vy[i] = 0.0;
        self.temp[i] = m.base_temperature();
        self.variant[i] = (self.rand() & 15) as u8;
        self.life[i] = match m {
            Mat::Fire => 20 + (self.rand() % 30) as u8,
            Mat::Smoke => 80 + (self.rand() % 100) as u8,
            Mat::Steam => 255,
            Mat::Ember => 80 + (self.rand() % 120) as u8,
            _ => 0,
        };
    }

    fn convert(&mut self, i: usize, m: Mat) {
        // like place() but keeps velocity (e.g. boiling water keeps moving)
        let kv = (self.vx[i], self.vy[i]);
        self.place(i, m);
        self.vx[i] = kv.0;
        self.vy[i] = kv.1;
    }

    fn swap_cells(&mut self, a: usize, b: usize) {
        self.mat.swap(a, b);
        self.vx.swap(a, b);
        self.vy.swap(a, b);
        self.temp.swap(a, b);
        self.life.swap(a, b);
        self.variant.swap(a, b);
        self.updated[a] = self.gen;
        self.updated[b] = self.gen;
    }

    // === Heat ===
    fn diffuse_heat(&mut self) {
        let w = self.width;
        let h = self.height;
        for y in 0..h {
            for x in 0..w {
                let i = self.idx(x, y);
                let m = Mat::from_u8(self.mat[i]);

                // Heat sources hold their temperature
                match m {
                    Mat::Fire => {
                        self.temp_back[i] = 650.0;
                        continue;
                    }
                    Mat::Ember => {
                        self.temp_back[i] = 600.0;
                        continue;
                    }
                    Mat::Lava => {
                        self.temp_back[i] = 1100.0;
                        continue;
                    }
                    _ => {}
                }

                let t = self.temp[i];
                let mut sum = 0.0;
                let mut cnt = 0.0;
                if x > 0 {
                    sum += self.temp[i - 1];
                    cnt += 1.0;
                }
                if x < w - 1 {
                    sum += self.temp[i + 1];
                    cnt += 1.0;
                }
                if y > 0 {
                    sum += self.temp[i - w as usize];
                    cnt += 1.0;
                }
                if y < h - 1 {
                    sum += self.temp[i + w as usize];
                    cnt += 1.0;
                }
                let avg = sum / cnt;
                let k = m.conductivity();
                let mut nt = t + (avg - t) * k;
                // slow ambient decay so the world doesn't stay hot forever
                nt += (AMBIENT - nt) * 0.004;
                // ice generates cold but can still be overwhelmed by real
                // heat (fire/lava nearby), unlike a hard-pinned temperature
                if m == Mat::Ice {
                    nt += (-25.0 - nt) * 0.25;
                }
                self.temp_back[i] = nt;
            }
        }
        std::mem::swap(&mut self.temp, &mut self.temp_back);
    }

    // === Per-cell update ===
    fn update_cell(&mut self, x: i32, y: i32) {
        let i = self.idx(x, y);
        if self.updated[i] == self.gen {
            return;
        }
        let m = Mat::from_u8(self.mat[i]);
        if m == Mat::Empty {
            return;
        }

        if self.react(x, y, i, m) {
            return;
        }

        if m.is_static() {
            return;
        }
        if m.is_gas() {
            self.update_gas(x, y, i, m);
        } else if m.is_liquid() {
            self.update_liquid(x, y, i, m);
        } else {
            self.update_powder(x, y, i, m);
        }
    }

    // Phase changes & chemistry. Returns true if the cell was consumed.
    fn react(&mut self, x: i32, y: i32, i: usize, m: Mat) -> bool {
        let t = self.temp[i];

        // -- temperature-driven phase changes --
        match m {
            Mat::Water => {
                if t > 100.0 && self.chance(4) {
                    self.convert(i, Mat::Steam);
                    return true;
                }
                if t < -2.0 && self.chance(6) {
                    self.place(i, Mat::Ice);
                    return true;
                }
            }
            Mat::SaltWater => {
                if t > 102.0 && self.chance(4) {
                    // boiling brine leaves salt behind sometimes
                    if self.chance(3) {
                        self.place(i, Mat::Salt);
                    } else {
                        self.convert(i, Mat::Steam);
                    }
                    return true;
                }
                if t < -12.0 && self.chance(8) {
                    self.place(i, Mat::Ice);
                    return true;
                }
            }
            Mat::Steam => {
                // mid-air condensation only when genuinely cold; otherwise
                // steam condenses on cool surfaces (see neighbor rules)
                if t < 45.0 && self.chance(10) {
                    self.convert(i, Mat::Water);
                    return true;
                }
            }
            Mat::Ice => {
                if t > 0.0 && self.chance(8) {
                    self.place(i, Mat::Water);
                    self.temp[i] = 5.0;
                    return true;
                }
            }
            Mat::Acid => {
                // boils into corrosive fumes
                if t > 120.0 && self.chance(8) {
                    self.convert(i, Mat::Smoke);
                    return true;
                }
            }
            Mat::Lava => {
                if t < 700.0 && self.chance(8) {
                    self.place(i, Mat::Stone);
                    self.temp[i] = 650.0;
                    return true;
                }
            }
            Mat::Stone => {
                if t > 950.0 && self.chance(40) {
                    self.place(i, Mat::Lava);
                    return true;
                }
            }
            Mat::Sand => {
                if t > 800.0 && self.chance(20) {
                    self.place(i, Mat::Glass);
                    self.temp[i] = t;
                    return true;
                }
            }
            Mat::Fire => {
                // fire dies out
                if self.life[i] == 0 {
                    if self.chance(2) {
                        self.convert(i, Mat::Smoke);
                    } else {
                        self.mat[i] = 0;
                        self.temp[i] = 200.0;
                    }
                    return true;
                }
                self.life[i] -= 1;
            }
            Mat::Smoke => {
                if self.life[i] == 0 {
                    self.mat[i] = 0;
                    return true;
                }
                self.life[i] -= 1;
            }
            Mat::Ember => {
                // burning solid: spawns flames, eventually collapses to ash
                if self.life[i] == 0 {
                    if self.chance(3) {
                        self.place(i, Mat::Ash);
                        self.temp[i] = 300.0;
                    } else {
                        self.convert(i, Mat::Smoke);
                    }
                    return true;
                }
                self.life[i] -= 1;
                if self.chance(6) {
                    let above = (x, y - 1);
                    if self.in_bounds(above.0, above.1) {
                        let ai = self.idx(above.0, above.1);
                        if self.mat[ai] == 0 {
                            self.place(ai, Mat::Fire);
                        }
                    }
                }
            }
            _ => {}
        }

        // -- ignition by heat --
        if let Some(ign) = m.ignition_temp() {
            if t > ign {
                match m {
                    Mat::Gunpowder => {
                        self.explode(x, y, 7);
                        return true;
                    }
                    Mat::Oil => {
                        if self.chance(2) {
                            self.convert(i, Mat::Fire);
                            return true;
                        }
                    }
                    Mat::Wood => {
                        if self.chance(6) {
                            self.place(i, Mat::Ember);
                            return true;
                        }
                    }
                    Mat::Plant => {
                        if self.chance(3) {
                            self.place(i, Mat::Ember);
                            self.life[i] = 25 + (self.rand() % 40) as u8;
                            return true;
                        }
                    }
                    _ => {}
                }
            }
        }

        // -- neighbor chemistry (checked on one random neighbor, cheap) --
        let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)];
        let (dx, dy) = dirs[(self.rand() as usize) & 3];
        let nx = x + dx;
        let ny = y + dy;
        if self.in_bounds(nx, ny) {
            let ni = self.idx(nx, ny);
            let nm = Mat::from_u8(self.mat[ni]);

            match (m, nm) {
                // --- direct-contact ignition (conduction alone is too weak
                //     for a single flame to reach ignition temperatures) ---
                (Mat::Oil, Mat::Fire) | (Mat::Oil, Mat::Ember) | (Mat::Oil, Mat::Lava) => {
                    if self.chance(2) {
                        self.convert(i, Mat::Fire);
                        return true;
                    }
                }
                (Mat::Wood, Mat::Fire) | (Mat::Wood, Mat::Ember) | (Mat::Wood, Mat::Lava) => {
                    if self.chance(10) {
                        self.place(i, Mat::Ember);
                        return true;
                    }
                }
                (Mat::Plant, Mat::Fire) | (Mat::Plant, Mat::Ember) | (Mat::Plant, Mat::Lava) => {
                    if self.chance(4) {
                        self.place(i, Mat::Ember);
                        self.life[i] = 25 + (self.rand() % 40) as u8;
                        return true;
                    }
                }
                (Mat::Gunpowder, Mat::Fire) | (Mat::Gunpowder, Mat::Ember) | (Mat::Gunpowder, Mat::Lava) => {
                    self.explode(x, y, 7);
                    return true;
                }

                // --- water fights fire ---
                (Mat::Fire, Mat::Water) | (Mat::Fire, Mat::SaltWater) => {
                    self.convert(i, Mat::Smoke);
                    if self.chance(3) {
                        self.convert(ni, Mat::Steam);
                    }
                    return true;
                }
                (Mat::Water, Mat::Fire) | (Mat::SaltWater, Mat::Fire) => {
                    self.convert(ni, Mat::Smoke);
                    if self.chance(3) {
                        self.convert(i, Mat::Steam);
                        return true;
                    }
                }
                (Mat::Ember, Mat::Water) | (Mat::Ember, Mat::SaltWater) => {
                    // douse: dying ember, burst of steam
                    self.place(i, Mat::Smoke);
                    self.convert(ni, Mat::Steam);
                    return true;
                }

                // --- lava ---
                (Mat::Lava, Mat::Water) | (Mat::Lava, Mat::SaltWater) => {
                    self.place(i, Mat::Obsidian);
                    self.convert(ni, Mat::Steam);
                    return true;
                }
                (Mat::Ice, Mat::Lava) => {
                    self.convert(i, Mat::Steam);
                    self.place(ni, Mat::Obsidian);
                    return true;
                }

                // --- salt (emergent only) ---
                (Mat::Salt, Mat::Water) => {
                    self.convert(ni, Mat::SaltWater);
                    self.mat[i] = 0;
                    return true;
                }
                (Mat::Salt, Mat::Ice) => {
                    if self.chance(4) {
                        self.place(ni, Mat::Water);
                        self.temp[ni] = 2.0;
                    }
                }

                // --- life ---
                (Mat::Water, Mat::Plant) => {
                    if self.chance(30) {
                        self.place(i, Mat::Plant);
                        return true;
                    }
                }

                // --- condensation on cool surfaces ---
                (Mat::Steam, _) if nm.is_static() && self.temp[ni] < 60.0 => {
                    if self.chance(8) {
                        self.convert(i, Mat::Water);
                        self.temp[i] = 40.0;
                        return true;
                    }
                }

                // --- cold ---
                (Mat::Ice, Mat::Water) => {
                    // creeping freeze
                    if self.temp[i] < -5.0 && self.chance(20) {
                        self.place(ni, Mat::Ice);
                    }
                }

                // --- acid ---
                (Mat::Acid, Mat::Water) | (Mat::Acid, Mat::SaltWater) => {
                    // dilution: water neutralizes acid
                    if self.chance(6) {
                        self.convert(i, Mat::Water);
                        return true;
                    }
                }
                (Mat::Acid, Mat::Lava) => {
                    // violent: acid flashes to toxic vapor
                    self.convert(i, Mat::Smoke);
                    self.temp[i] = 300.0;
                    return true;
                }
                (Mat::Acid, _) if nm.is_solid() && nm != Mat::Glass && nm != Mat::Obsidian => {
                    if self.chance(8) {
                        self.mat[ni] = 0;
                        self.temp[ni] = 60.0;
                        // corrosion releases fumes and spends the acid
                        if self.chance(3) {
                            self.convert(i, Mat::Smoke);
                            return true;
                        }
                    }
                }
                _ => {}
            }
        }

        false
    }

    // === Movement: powders ===
    fn update_powder(&mut self, x: i32, y: i32, i: usize, m: Mat) {
        self.vy[i] = (self.vy[i] + GRAVITY).min(MAX_FALL);
        self.vx[i] *= 0.85;

        match self.try_velocity_move(x, y, i, m) {
            MoveResult::Moved => return,
            // mid-air with sub-cell speed: let velocity build up
            MoveResult::NoStep if !self.supported(x, y, m) => return,
            _ => {}
        }

        // blocked: impact scatter converts fall speed into sideways kick
        let impact = self.vy[i];
        if impact > 2.0 {
            let kick = (self.frand() - 0.5) * impact * 0.6;
            self.vx[i] += kick;
        }
        self.vy[i] = 0.0;

        // classic diagonal settle
        let dir = if self.rand() & 1 == 0 { 1 } else { -1 };
        for &d in &[dir, -dir] {
            let nx = x + d;
            let ny = y + 1;
            if !self.in_bounds(nx, ny) {
                continue;
            }
            let ni = self.idx(nx, ny);
            let nm = Mat::from_u8(self.mat[ni]);
            if nm == Mat::Empty || (!nm.is_solid() && nm.density() < m.density()) {
                self.swap_cells(i, ni);
                return;
            }
        }
    }

    // === Movement: liquids ===
    fn update_liquid(&mut self, x: i32, y: i32, i: usize, m: Mat) {
        self.vy[i] = (self.vy[i] + GRAVITY).min(MAX_FALL);

        match self.try_velocity_move(x, y, i, m) {
            MoveResult::Moved => return,
            MoveResult::NoStep if !self.supported(x, y, m) => return,
            _ => {}
        }

        // hit something: splash sideways with energy from the fall
        let impact = self.vy[i];
        if impact > 1.5 {
            self.vx[i] += (self.frand() - 0.5) * impact * 1.0;
        }
        self.vy[i] = 0.0;

        // diagonal flow
        let dir = if self.vx[i] > 0.1 {
            1
        } else if self.vx[i] < -0.1 {
            -1
        } else if self.rand() & 1 == 0 {
            1
        } else {
            -1
        };
        for &d in &[dir, -dir] {
            let nx = x + d;
            let ny = y + 1;
            if !self.in_bounds(nx, ny) {
                continue;
            }
            let ni = self.idx(nx, ny);
            let nm = Mat::from_u8(self.mat[ni]);
            if nm == Mat::Empty || (!nm.is_solid() && nm.density() < m.density()) {
                self.swap_cells(i, ni);
                return;
            }
        }

        // horizontal dispersion: march up to N cells toward dir, fall into gaps
        let disp = match m {
            Mat::Lava => 1,
            Mat::Oil => 3,
            _ => 4,
        };
        let mut cur = i;
        let mut cx = x;
        for _ in 0..disp {
            let nx = cx + dir;
            if !self.in_bounds(nx, y) {
                break;
            }
            let ni = self.idx(nx, y);
            let nm = Mat::from_u8(self.mat[ni]);
            if nm == Mat::Empty {
                self.swap_cells(cur, ni);
                cur = ni;
                cx = nx;
                // drop into holes while flowing
                if y + 1 < self.height {
                    let bi = self.idx(nx, y + 1);
                    if self.mat[bi] == 0 {
                        self.swap_cells(cur, bi);
                        return;
                    }
                }
            } else if !nm.is_solid() && nm.density() < m.density() {
                self.swap_cells(cur, ni);
                return;
            } else {
                // wall: bounce flow direction
                self.vx[cur] = -self.vx[cur] * 0.5;
                break;
            }
        }
    }

    // === Movement: gases ===
    fn update_gas(&mut self, x: i32, y: i32, i: usize, m: Mat) {
        // buoyancy + lateral wander
        let rise = match m {
            Mat::Fire => 0.4,
            Mat::Steam => 0.3,
            _ => 0.22,
        };
        self.vy[i] = (self.vy[i] - rise).max(-1.6);
        self.vx[i] = (self.vx[i] + (self.frand() - 0.5) * 0.6).clamp(-1.5, 1.5);

        if self.try_velocity_move(x, y, i, m) == MoveResult::Moved {
            return;
        }
        self.vy[i] *= 0.3;

        // spread sideways under a ceiling
        let dir = if self.rand() & 1 == 0 { 1 } else { -1 };
        for &d in &[dir, -dir] {
            let nx = x + d;
            if !self.in_bounds(nx, y) {
                continue;
            }
            let ni = self.idx(nx, y);
            if self.mat[ni] == 0 {
                self.swap_cells(i, ni);
                return;
            }
        }
    }

    // Move along the velocity vector, stepping cell by cell.
    fn try_velocity_move(&mut self, x: i32, y: i32, i: usize, m: Mat) -> MoveResult {
        let vx = self.vx[i];
        let vy = self.vy[i];
        // sub-cell velocity: no step this tick, keep accumulating
        if vx.abs().max(vy.abs()).round() < 1.0 {
            return MoveResult::NoStep;
        }
        let steps = (vx.abs().max(vy.abs()).ceil() as i32).min(8);

        let mut cur = i;
        let mut cx = x;
        let mut cy = y;
        let mut moved = false;

        for s in 1..=steps {
            let tx = x + ((vx * s as f32) / steps as f32).round() as i32;
            let ty = y + ((vy * s as f32) / steps as f32).round() as i32;
            if tx == cx && ty == cy {
                continue;
            }
            if !self.in_bounds(tx, ty) {
                // hitting the floor/walls kills velocity
                self.vx[cur] *= 0.3;
                self.vy[cur] = 0.0;
                return if moved { MoveResult::Moved } else { MoveResult::Blocked };
            }
            let ti = self.idx(tx, ty);
            let tm = Mat::from_u8(self.mat[ti]);

            let passable = tm == Mat::Empty
                || (!tm.is_static()
                    && if m.is_gas() {
                        // gases only rise through liquids
                        tm.is_liquid()
                    } else {
                        tm.density() < m.density() && !tm.is_powder()
                    });

            if passable {
                if tm != Mat::Empty {
                    // sinking through a fluid is slow
                    self.vy[cur] *= 0.6;
                }
                self.swap_cells(cur, ti);
                cur = ti;
                cx = tx;
                cy = ty;
                moved = true;
            } else {
                return if moved { MoveResult::Moved } else { MoveResult::Blocked };
            }
        }
        if moved { MoveResult::Moved } else { MoveResult::NoStep }
    }

    // Is the cell resting on something it can't fall through?
    fn supported(&self, x: i32, y: i32, m: Mat) -> bool {
        if y + 1 >= self.height {
            return true;
        }
        let bm = Mat::from_u8(self.mat[self.idx(x, y + 1)]);
        if bm == Mat::Empty {
            return false;
        }
        bm.is_static() || bm.is_powder() || bm.density() >= m.density()
    }

    // === Explosions ===
    fn explode(&mut self, x: i32, y: i32, radius: i32) {
        let r2 = radius * radius;
        for dy in -radius..=radius {
            for dx in -radius..=radius {
                let d2 = dx * dx + dy * dy;
                if d2 > r2 {
                    continue;
                }
                let nx = x + dx;
                let ny = y + dy;
                if !self.in_bounds(nx, ny) {
                    continue;
                }
                let ni = self.idx(nx, ny);
                let nm = Mat::from_u8(self.mat[ni]);
                let dist = (d2 as f32).sqrt().max(1.0);
                let falloff = 1.0 - dist / radius as f32;

                // blast heat ignites/chains everything nearby
                self.temp[ni] += 500.0 * falloff;

                if matches!(nm, Mat::Stone | Mat::Obsidian | Mat::Metal | Mat::Glass) {
                    continue;
                }

                if nm == Mat::Empty {
                    if falloff > 0.3 && self.chance(2) {
                        let debris = if self.chance(2) { Mat::Fire } else { Mat::Smoke };
                        self.place(ni, debris);
                    }
                }

                // shockwave: throw particles outward
                let power = 9.0 * falloff;
                self.vx[ni] += (dx as f32 / dist) * power;
                self.vy[ni] += (dy as f32 / dist) * power - 2.0 * falloff;
            }
        }
        // the core becomes fire
        let i = self.idx(x, y);
        self.place(i, Mat::Fire);
        self.life[i] = 30;
    }

    #[inline]
    fn chance(&mut self, one_in: u32) -> bool {
        self.rand() % one_in == 0
    }
}

fn lerp_u8(a: u8, b: u8, t: f32) -> u8 {
    (a as f32 + (b as f32 - a as f32) * t.clamp(0.0, 1.0)) as u8
}

// Thermal camera palette: bright icy cyan (cold) -> dark (ambient) ->
// red/orange -> white (hot). Ambient ~20C sits near black so both cold
// and hot regions pop.
fn heat_color(t: f32) -> (u8, u8, u8) {
    if t < 15.0 {
        // 15C..-30C ramps dark -> bright icy blue
        let cold = ((15.0 - t) / 45.0).clamp(0.0, 1.0);
        (
            (40.0 * cold) as u8,
            (40.0 + 160.0 * cold) as u8,
            (70.0 + 185.0 * cold) as u8,
        )
    } else {
        // 15C..1200C ramps dark -> red -> orange -> white
        let v = ((t - 15.0) / 1185.0).clamp(0.0, 1.0);
        let r = (v * 2.5).min(1.0);
        let g = ((v - 0.35) * 1.6).clamp(0.0, 1.0);
        let b = ((v - 0.75) * 3.0).clamp(0.0, 1.0);
        ((r * 255.0) as u8, (g * 255.0) as u8, (b * 255.0) as u8)
    }
}
