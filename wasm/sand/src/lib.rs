use wasm_bindgen::prelude::*;

#[wasm_bindgen]
#[repr(u8)]
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Cell {
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
}

impl Cell {
    fn from_u8(v: u8) -> Cell {
        if v > 15 {
            return Cell::Empty;
        }
        unsafe { std::mem::transmute(v) }
    }

    fn is_solid(&self) -> bool {
        match self {
            Cell::Sand
            | Cell::Stone
            | Cell::Wood
            | Cell::Plant
            | Cell::Ice
            | Cell::Glass
            | Cell::Obsidian
            | Cell::Gunpowder => true,
            _ => false,
        }
    }

    fn is_liquid(&self) -> bool {
        match self {
            Cell::Water | Cell::Oil | Cell::Acid | Cell::Lava => true,
            _ => false,
        }
    }

    fn is_gas(&self) -> bool {
        match self {
            Cell::Fire | Cell::Steam | Cell::Smoke => true,
            _ => false,
        }
    }

    fn is_static(&self) -> bool {
        match self {
            Cell::Stone | Cell::Wood | Cell::Plant | Cell::Ice | Cell::Glass | Cell::Obsidian => {
                true
            }
            _ => false,
        }
    }

    fn density(&self) -> i8 {
        match self {
            Cell::Stone | Cell::Obsidian => 100,
            Cell::Glass => 60,
            Cell::Sand => 50,
            Cell::Ice => 25,
            Cell::Water | Cell::Acid => 30,
            Cell::Lava => 40,
            Cell::Oil => 10,
            Cell::Wood | Cell::Plant => 20,
            Cell::Gunpowder => 45,
            Cell::Fire | Cell::Steam | Cell::Smoke => -10,
            Cell::Empty => 0,
        }
    }

    fn base_temperature(&self) -> i16 {
        match self {
            Cell::Fire => 800,
            Cell::Lava => 30000,
            Cell::Ice => -20,
            Cell::Steam => 300,
            Cell::Smoke => 300,
            Cell::Water | Cell::Acid | Cell::Oil => 20,
            Cell::Plant => 20,
            Cell::Sand
            | Cell::Stone
            | Cell::Wood
            | Cell::Glass
            | Cell::Obsidian
            | Cell::Gunpowder => 20,
            Cell::Empty => 20,
        }
    }

    fn flammability(&self) -> u8 {
        match self {
            Cell::Wood => 60,
            Cell::Plant => 60,
            Cell::Oil => 90,
            Cell::Gunpowder => 100,
            _ => 0,
        }
    }
}

#[wasm_bindgen]
pub struct Universe {
    width: u32,
    height: u32,
    cells: Vec<u8>,
    temps: Vec<i16>,
    temps_back: Vec<i16>,
    moved: Vec<bool>,
    rng: u32,
    generation: u8,
}

#[wasm_bindgen]
impl Universe {
    pub fn new(width: u32, height: u32) -> Universe {
        let count = (width * height) as usize;
        let cells = vec![Cell::Empty as u8; count];
        let temps = vec![20; count];
        let temps_back = vec![20; count];
        let moved = vec![false; count];

        Universe {
            width,
            height,
            cells,
            temps,
            temps_back,
            moved,
            rng: 0xB45BE,
            generation: 0,
        }
    }

    pub fn width(&self) -> u32 {
        self.width
    }
    pub fn height(&self) -> u32 {
        self.height
    }
    pub fn cells(&self) -> *const u8 {
        self.cells.as_ptr()
    }

    pub fn tick(&mut self) {
        self.generation = self.generation.wrapping_add(1);

        // Reset moved status
        self.moved.fill(false);

        self.diffuse_heat();

        if self.generation % 2 == 0 {
            for row in (0..self.height).rev() {
                for col in 0..self.width {
                    self.update_pixel(row, col);
                }
            }
        } else {
            for row in (0..self.height).rev() {
                for col in (0..self.width).rev() {
                    self.update_pixel(row, col);
                }
            }
        }
    }

    fn diffuse_heat(&mut self) {
        for y in 0..self.height {
            for x in 0..self.width {
                let idx = self.get_index(y, x);
                let cell = Cell::from_u8(self.cells[idx]);

                match cell {
                    Cell::Fire => {
                        self.temps_back[idx] = 800;
                        continue;
                    }
                    Cell::Ice => {
                        self.temps_back[idx] = -20;
                        continue;
                    }
                    _ => {}
                }

                let mut sum: i32 = (self.temps[idx] as i32) * 1024;
                let mut count = 1024;

                let dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)];
                for (dy, dx) in dirs.iter() {
                    let ny = y as i32 + dy;
                    let nx = x as i32 + dx;
                    if ny >= 0 && ny < self.height as i32 && nx >= 0 && nx < self.width as i32 {
                        let nidx = self.get_index(ny as u32, nx as u32);
                        sum += self.temps[nidx] as i32;
                        count += 1;
                    }
                }

                let mut avg = (sum / count) as i16;

                if cell == Cell::Empty {
                    if (idx + self.generation as usize) % 10 == 0 {
                        if avg > 20 {
                            avg -= 1;
                        } else if avg < 20 {
                            avg += 1;
                        }
                    }
                }

                self.temps_back[idx] = avg;
            }
        }

        std::mem::swap(&mut self.temps, &mut self.temps_back);
    }

    fn update_pixel(&mut self, row: u32, col: u32) {
        let idx = self.get_index(row, col);

        if self.moved[idx] {
            return;
        }

        let cell_u8 = self.cells[idx];
        let cell = Cell::from_u8(cell_u8);
        if cell == Cell::Empty {
            return;
        }

        let temp = self.temps[idx];

        match cell {
            Cell::Water => {
                if temp > 100 {
                    if (self.rand() % 10) == 0 {
                        self.set_cell(row, col, Cell::Steam);
                    }
                    return;
                }
                if temp < -5 {
                    if (self.rand() % 10) == 0 {
                        self.set_cell(row, col, Cell::Ice);
                    }
                    return;
                }
            }
            Cell::Ice => {
                if temp > 0 {
                    if (self.rand() % 20) == 0 {
                        self.set_cell(row, col, Cell::Water);
                    }
                    return;
                }
            }
            Cell::Lava => {
                if temp < 800 {
                    if (self.rand() % 10) == 0 {
                        self.set_cell(row, col, Cell::Stone);
                        self.temps[idx] = temp;
                    }
                    return;
                }
            }
            Cell::Sand => {
                if temp > 500 {
                    // Melt
                    if (self.rand() % 50) == 0 {
                        self.set_cell(row, col, Cell::Glass);
                    }
                    return;
                }
            }
            Cell::Fire => {
                if (self.rand() & 15) == 0 {
                    if (self.rand() & 1) == 0 {
                        self.set_cell(row, col, Cell::Smoke);
                    } else {
                        self.set_cell(row, col, Cell::Empty);
                    }
                    return;
                }
            }
            Cell::Smoke => {
                if (self.rand() & 15) == 0 {
                    self.set_cell(row, col, Cell::Empty);
                    return;
                }
            }
            Cell::Steam => {
                if temp < 80 {
                    if (self.rand() % 20) == 0 {
                        self.set_cell(row, col, Cell::Water);
                    }
                    return;
                }
            }
            _ => {}
        }

        if cell == Cell::Ice
            || cell == Cell::Lava
            || cell == Cell::Acid
            || cell == Cell::Oil
            || cell == Cell::Gunpowder
        {
            let neighbors = [(0, 1), (0, -1), (1, 0), (-1, 0)];
            for (dy, dx) in neighbors.iter() {
                let ny = row as i32 + dy;
                let nx = col as i32 + dx;
                if ny >= 0 && ny < self.height as i32 && nx >= 0 && nx < self.width as i32 {
                    let nidx = self.get_index(ny as u32, nx as u32);
                    let ncell = Cell::from_u8(self.cells[nidx]);

                    if cell == Cell::Ice && ncell == Cell::Lava {
                        self.set_cell(row, col, Cell::Steam);
                        self.set_cell(ny as u32, nx as u32, Cell::Obsidian);
                        return;
                    }

                    if cell == Cell::Gunpowder {
                        if ncell == Cell::Fire || ncell == Cell::Lava {
                            self.explode(row, col);
                            return;
                        }
                    }
                }
            }
        }

        if (self.rand() & 7) == 0 {
            let neighbors = [(0, 1), (0, -1), (1, 0), (-1, 0)];
            let (dy, dx) = neighbors[(self.rand() as usize) % 4];
            let ny = row as i32 + dy;
            let nx = col as i32 + dx;

            if ny >= 0 && ny < self.height as i32 && nx >= 0 && nx < self.width as i32 {
                let nidx = self.get_index(ny as u32, nx as u32);
                let ncell = Cell::from_u8(self.cells[nidx]);

                if cell == Cell::Acid {
                    if ncell == Cell::Lava {
                        self.set_cell(row, col, Cell::Fire);
                        self.set_cell(ny as u32, nx as u32, Cell::Steam);
                        return;
                    }
                    if ncell == Cell::Stone || ncell == Cell::Obsidian {
                        if (self.rand() % 20) == 0 {
                            self.set_cell(ny as u32, nx as u32, Cell::Sand);
                            if (self.rand() % 2) == 0 {
                                self.set_cell(row, col, Cell::Empty);
                            }
                        }
                        return;
                    }
                    if ncell == Cell::Wood || ncell == Cell::Plant || ncell == Cell::Gunpowder {
                        if (self.rand() % 10) == 0 {
                            self.set_cell(ny as u32, nx as u32, Cell::Smoke);
                            self.set_cell(row, col, Cell::Empty);
                        }
                        return;
                    }
                }

                if cell == Cell::Lava {
                    if ncell == Cell::Water {
                        self.set_cell(row, col, Cell::Obsidian);
                        self.set_cell(ny as u32, nx as u32, Cell::Steam);
                        return;
                    }

                    if ncell == Cell::Wood || ncell == Cell::Plant || ncell == Cell::Gunpowder {
                        self.set_cell(ny as u32, nx as u32, Cell::Fire);
                    }
                    if ncell == Cell::Oil {
                        self.set_cell(ny as u32, nx as u32, Cell::Fire);
                    }
                }

                if cell == Cell::Water && ncell == Cell::Plant {
                    if (self.rand() % 20) == 0 {
                        self.set_cell(row, col, Cell::Plant);
                    }
                }

                if ncell == Cell::Fire || ncell == Cell::Lava {
                    let prob = cell.flammability();
                    if prob > 0 && ((self.rand() as u8) % 100 < prob) {
                        self.set_cell(row, col, Cell::Fire);
                        return;
                    }
                }
            }
        }

        if cell.is_static() {
            return;
        }

        if cell.is_gas() {
            self.move_gas(row, col, cell_u8, cell);
        } else {
            self.move_solid_liquid(row, col, cell_u8, cell);
        }
    }

    fn move_solid_liquid(&mut self, row: u32, col: u32, _cell_u8: u8, cell: Cell) {
        if row == self.height - 1 {
            return;
        }

        let idx = self.get_index(row, col);
        let below_idx = self.get_index(row + 1, col);
        let below_cell = Cell::from_u8(self.cells[below_idx]);

        if below_cell == Cell::Empty
            || (cell.density() > below_cell.density() && !below_cell.is_solid())
        {
            self.swap(idx, below_idx);
            return;
        }

        let spread = self.toss_coin();
        let dirs = if spread { [-1, 1] } else { [1, -1] };

        for &dir in &dirs {
            let target_col = col as i32 + dir;
            if target_col >= 0 && target_col < self.width as i32 {
                let t_col = target_col as u32;
                let diag_idx = self.get_index(row + 1, t_col);
                let diag_cell = Cell::from_u8(self.cells[diag_idx]);

                if diag_cell == Cell::Empty
                    || (cell.density() > diag_cell.density() && !diag_cell.is_solid())
                {
                    self.swap(idx, diag_idx);
                    return;
                }
            }
        }

        if cell.is_liquid() {
            for &dir in &dirs {
                let target_col = col as i32 + dir;
                if target_col >= 0 && target_col < self.width as i32 {
                    let t_col = target_col as u32;
                    let side_idx = self.get_index(row, t_col);
                    let side_cell = Cell::from_u8(self.cells[side_idx]);

                    if side_cell == Cell::Empty
                        || (cell.density() > side_cell.density() && !side_cell.is_solid())
                    {
                        self.swap(idx, side_idx);
                        return;
                    }
                }
            }
            for &dir in &dirs {
                let target_col = col as i32 + (dir * 2);
                if target_col >= 0 && target_col < self.width as i32 {
                    let mid_col = (col as i32 + dir) as u32;
                    let mid_idx = self.get_index(row, mid_col);
                    let mid_cell = Cell::from_u8(self.cells[mid_idx]);

                    if mid_cell == cell {
                        let t_col = target_col as u32;
                        let side_idx = self.get_index(row, t_col);
                        let side_cell = Cell::from_u8(self.cells[side_idx]);
                        if side_cell == Cell::Empty {
                            self.swap(idx, side_idx);
                            return;
                        }
                    }
                }
            }
        }
    }

    fn move_gas(&mut self, row: u32, col: u32, _cell_u8: u8, _cell: Cell) {
        if row == 0 {
            return;
        }

        let idx = self.get_index(row, col);
        let above_idx = self.get_index(row - 1, col);
        let above_cell = Cell::from_u8(self.cells[above_idx]);

        if above_cell == Cell::Empty || above_cell.is_liquid() {
            self.swap(idx, above_idx);
            return;
        }

        let spread = self.toss_coin();
        let dirs = if spread { [-1, 1] } else { [1, -1] };

        for &dir in &dirs {
            let target_col = col as i32 + dir;
            if target_col >= 0 && target_col < self.width as i32 {
                let t_col = target_col as u32;
                let diag_idx = self.get_index(row - 1, t_col);
                let diag_cell = Cell::from_u8(self.cells[diag_idx]);

                if diag_cell == Cell::Empty || diag_cell.is_liquid() {
                    self.swap(idx, diag_idx);
                    return;
                }
            }
        }

        for &dir in &dirs {
            let target_col = col as i32 + dir;
            if target_col >= 0 && target_col < self.width as i32 {
                let t_col = target_col as u32;
                let side_idx = self.get_index(row, t_col);
                let side_cell = Cell::from_u8(self.cells[side_idx]);

                if side_cell == Cell::Empty {
                    self.swap(idx, side_idx);
                    return;
                }
            }
        }
    }

    fn swap(&mut self, idx1: usize, idx2: usize) {
        self.cells.swap(idx1, idx2);
        self.temps.swap(idx1, idx2);
        self.moved[idx1] = true;
        self.moved[idx2] = true;
    }

    fn set_cell(&mut self, row: u32, col: u32, cell: Cell) {
        let idx = self.get_index(row, col);
        self.cells[idx] = cell as u8;
        if cell != Cell::Empty {
            self.temps[idx] = cell.base_temperature();
        }
    }

    pub fn paint(&mut self, row: u32, col: u32, color_val: u8, radius: i32) {
        let r_squared = radius * radius;
        let cell = Cell::from_u8(color_val);

        for r in -radius..=radius {
            for c in -radius..=radius {
                if r * r + c * c <= r_squared {
                    let target_row = (row as i32 + r) as i32;
                    let target_col = (col as i32 + c) as i32;

                    if target_row >= 0
                        && target_row < self.height as i32
                        && target_col >= 0
                        && target_col < self.width as i32
                    {
                        self.set_cell(target_row as u32, target_col as u32, cell);
                    }
                }
            }
        }
    }

    fn explode(&mut self, row: u32, col: u32) {
        self.paint(row, col, Cell::Fire as u8, 3);
        for _ in 0..10 {
            let dy = (self.rand() % 10) as i32 - 5;
            let dx = (self.rand() % 10) as i32 - 5;
            let ny = row as i32 + dy;
            let nx = col as i32 + dx;
            if ny >= 0 && ny < self.height as i32 && nx >= 0 && nx < self.width as i32 {
                let existing = Cell::from_u8(self.cells[self.get_index(ny as u32, nx as u32)]);
                if existing == Cell::Stone || existing == Cell::Obsidian || existing == Cell::Glass {
                    continue;
                }
                if (self.rand() % 2) == 0 {
                    self.set_cell(ny as u32, nx as u32, Cell::Fire);
                } else {
                    self.set_cell(ny as u32, nx as u32, Cell::Smoke);
                }
            }
        }
    }

    pub fn clear(&mut self) {
        self.cells.fill(Cell::Empty as u8);
        self.temps.fill(20);
        self.temps_back.fill(20);
        self.moved.fill(false);
    }

    fn get_index(&self, row: u32, col: u32) -> usize {
        (row * self.width + col) as usize
    }

    fn rand(&mut self) -> u32 {
        let mut x = self.rng;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.rng = x;
        x
    }

    fn toss_coin(&mut self) -> bool {
        self.rand() & 1 == 0
    }
}
