use wasm_bindgen::prelude::*;
use std::iter;

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
    Ash = 6,
    Oil = 7,
    Acid = 8,
    Lava = 9,
    Plant = 10,
}

impl Cell {
    fn is_solid(&self) -> bool {
        match self {
            Cell::Sand | Cell::Ash => true,
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
            Cell::Fire => true,
            _ => false,
        }
    }
    
    fn is_static(&self) -> bool {
        match self {
            Cell::Stone | Cell::Wood | Cell::Plant => true,
            _ => false,
        }
    }

    fn density(&self) -> i8 {
        match self {
            Cell::Stone => 100,
            Cell::Sand => 10,
            Cell::Ash => 10,
            Cell::Water => 5,
            Cell::Acid => 5,
            Cell::Lava => 20,
            Cell::Oil => 3,
            Cell::Wood => 8, // Floats on water (if we had complex interactions), currently static
            Cell::Fire => -1, // Rises
            Cell::Empty => 0,
            Cell::Plant => 8,
        }
    }
    
    // Check if this cell can displace the target cell based on density
    fn can_displace(&self, target: Cell) -> bool {
        if self.is_static() || target.is_static() {
            return false;
        }
        
        // Solid/Liquid behavior: heavier displaces lighter
        if (self.is_solid() || self.is_liquid()) {
            if target == Cell::Empty {
                return true;
            }
            // Swap if I'm heavier than target
            return self.density() > target.density();
        }
        
        // Gas behavior: lighter displaces heavier (or rather, moves into empty)
        if self.is_gas() {
             if target == Cell::Empty {
                return true;
            }
            // Gas moves through liquids? maybe. For now just move into Empty.
            // Or displace heavier? -1 < 5.
            // Let's keep gas simple: only move into empty or other gases
             return false;
        }
        
        false
    }
}

#[wasm_bindgen]
pub struct Universe {
    width: u32,
    height: u32,
    cells: Vec<u8>,
    rng: u32,
    generation: u8,
}

#[wasm_bindgen]
impl Universe {
    pub fn new(width: u32, height: u32) -> Universe {
        let cells = (0..width * height)
            .map(|_| Cell::Empty as u8)
            .collect();

        Universe {
            width,
            height,
            cells,
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
        let current_gen = self.generation;
        
        // Pass 1: Gravity (Solids and Liquids) - Iterate Bottom-Up
        for row in (0..self.height - 1).rev() {
            // Alternate iteration direction to fix left/right bias
            if current_gen % 2 == 0 {
                for col in 0..self.width {
                    self.update_pixel(row, col);
                }
            } else {
                for col in (0..self.width).rev() {
                    self.update_pixel(row, col);
                }
            }
        }

        // Pass 2: Buoyancy (Gases) - Iterate Top-Down
        for row in 1..self.height {
             if current_gen % 2 == 0 {
                for col in 0..self.width {
                    self.update_gas_pixel(row, col);
                }
            } else {
                for col in (0..self.width).rev() {
                    self.update_gas_pixel(row, col);
                }
            }
        }
    }
    
    fn update_pixel(&mut self, row: u32, col: u32) {
        let idx = self.get_index(row, col);
        let cell_u8 = self.cells[idx];
        
        if cell_u8 == Cell::Empty as u8 {
            return;
        }

        // Unsafe purely for speed, we trust u8 matches enum
        let cell = unsafe { std::mem::transmute::<u8, Cell>(cell_u8) };

        if cell.is_static() || cell.is_gas() {
            return;
        }

        if cell.is_solid() || cell.is_liquid() {
            self.update_gravity_body(row, col, cell_u8, cell);
        }
    }
    
    fn update_gas_pixel(&mut self, row: u32, col: u32) {
        let idx = self.get_index(row, col);
        let cell_u8 = self.cells[idx];
        if cell_u8 == Cell::Empty as u8 {
            return;
        }
        let cell = unsafe { std::mem::transmute::<u8, Cell>(cell_u8) };
        if cell.is_gas() {
            self.update_gas_body(row, col, cell_u8);
        }
    }

    pub fn paint(&mut self, row: u32, col: u32, color_val: u8, radius: i32) {
        let r_squared = radius * radius;
        
        for r in -radius..=radius {
            for c in -radius..=radius {
                if r*r + c*c <= r_squared {
                    let target_row = (row as i32 + r) as i32;
                    let target_col = (col as i32 + c) as i32;
                    
                    if target_row >= 0 && target_row < self.height as i32 && 
                       target_col >= 0 && target_col < self.width as i32 {
                        let idx = self.get_index(target_row as u32, target_col as u32);
                        self.cells[idx] = color_val;
                    }
                }
            }
        }
    }
    
    pub fn clear(&mut self) {
        self.cells = iter::repeat(Cell::Empty as u8).take((self.width * self.height) as usize).collect();
    }
}

// Private helpers
impl Universe {
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
    
    // Returns true/false with 50% probability
    fn toss_coin(&mut self) -> bool {
        self.rand() & 1 == 0
    }

    fn update_gravity_body(&mut self, row: u32, col: u32, cell_u8: u8, cell: Cell) {
        let idx = self.get_index(row, col);
        let below_idx = self.get_index(row + 1, col);
        let below_cell_u8 = self.cells[below_idx];
        let below_cell = unsafe { std::mem::transmute::<u8, Cell>(below_cell_u8) };

        // 1. Try moving down (displaces if denser)
        // If empty, simple move
        if below_cell == Cell::Empty {
            self.cells[below_idx] = cell_u8;
            self.cells[idx] = Cell::Empty as u8;
            return;
        } else if cell.can_displace(below_cell) {
             // Swap
             self.cells[below_idx] = cell_u8;
             self.cells[idx] = below_cell_u8;
             return;
        }

        // 2. Try moving randomly diagonally
        let spread_decision = self.toss_coin();
        let (first_dir, second_dir) = if spread_decision { (-1, 1) } else { (1, -1) };

        let can_go_left = col > 0;
        let can_go_right = col < self.width - 1;

        // Helper check for diagonal move/swap
        let check_and_move = |universe: &mut Universe, current_idx: usize, current_row: u32, target_col: u32| -> bool {
             let diag_idx = universe.get_index(current_row + 1, target_col);
             let other_cell_u8 = universe.cells[diag_idx];
             let other_cell = unsafe { std::mem::transmute::<u8, Cell>(other_cell_u8) };
             
             if other_cell == Cell::Empty {
                 universe.cells[diag_idx] = cell_u8;
                 universe.cells[current_idx] = Cell::Empty as u8;
                 return true;
             } else if cell.can_displace(other_cell) {
                 universe.cells[diag_idx] = cell_u8;
                 universe.cells[current_idx] = other_cell_u8;
                 return true;
             }
             false
        };

        if (first_dir == -1 && can_go_left) || (first_dir == 1 && can_go_right) {
            let target_col = (col as i32 + first_dir) as u32;
            if check_and_move(self, idx, row, target_col) { return; }
        }

        if (second_dir == -1 && can_go_left) || (second_dir == 1 && can_go_right) {
             let target_col = (col as i32 + second_dir) as u32;
             if check_and_move(self, idx, row, target_col) { return; }
        }

        // 3. If liquid, try moving horizontally
        if cell.is_liquid() {
            let (h_first, h_second) = if spread_decision { (-1, 1) } else { (1, -1) };
            
            let check_slide = |universe: &mut Universe, current_idx: usize, current_row: u32, target_col: u32| -> bool {
                let side_idx = universe.get_index(current_row, target_col);
                let other_cell_u8 = universe.cells[side_idx];
                let other_cell = unsafe { std::mem::transmute::<u8, Cell>(other_cell_u8) };
                
                if other_cell == Cell::Empty {
                    universe.cells[side_idx] = cell_u8;
                    universe.cells[current_idx] = Cell::Empty as u8;
                    return true;
                } else if cell.can_displace(other_cell) {
                     universe.cells[side_idx] = cell_u8;
                     universe.cells[current_idx] = other_cell_u8;
                     return true;
                }
                false
            };

            if (h_first == -1 && can_go_left) || (h_first == 1 && can_go_right) {
                let target_col = (col as i32 + h_first) as u32;
                if check_slide(self, idx, row, target_col) { return; }
            }
            
            if (h_second == -1 && can_go_left) || (h_second == 1 && can_go_right) {
                let target_col = (col as i32 + h_second) as u32;
                if check_slide(self, idx, row, target_col) { return; }
            }
        }
    }

    fn update_gas_body(&mut self, row: u32, col: u32, cell_u8: u8) {
        let idx = self.get_index(row, col);
        let above_idx = self.get_index(row - 1, col);

        // 1. Try moving up
        if self.cells[above_idx] == Cell::Empty as u8 {
            self.cells[above_idx] = cell_u8;
            self.cells[idx] = Cell::Empty as u8;
            return;
        }
        
        // Gases don't really "displace" solids/liquids easily in this simple model, 
        // they bubble up through them if we implement that, but user asked for "sinking/floating".
        // With current density map, Gas(-1) < Water(5), so Gas should float up through water?
        // My can_displace on Gas returned false. 
        // Let's defer bubbling for now, focus on Empty.

        // 2. Try moving randomly diagonally up
        let spread_decision = self.toss_coin();
        let (first_dir, second_dir) = if spread_decision { (-1, 1) } else { (1, -1) };

        let can_go_left = col > 0;
        let can_go_right = col < self.width - 1;

        if (first_dir == -1 && can_go_left) || (first_dir == 1 && can_go_right) {
            let target_col = (col as i32 + first_dir) as u32;
            let diag_idx = self.get_index(row - 1, target_col);
            if self.cells[diag_idx] == Cell::Empty as u8 {
                self.cells[diag_idx] = cell_u8;
                self.cells[idx] = Cell::Empty as u8;
                return;
            }
        }

        if (second_dir == -1 && can_go_left) || (second_dir == 1 && can_go_right) {
            let target_col = (col as i32 + second_dir) as u32;
            let diag_idx = self.get_index(row - 1, target_col);
            if self.cells[diag_idx] == Cell::Empty as u8 {
                self.cells[diag_idx] = cell_u8;
                self.cells[idx] = Cell::Empty as u8;
                return;
            }
        }
        
        let (h_first, h_second) = if spread_decision { (-1, 1) } else { (1, -1) };
            
        if (h_first == -1 && can_go_left) || (h_first == 1 && can_go_right) {
            let target_col = (col as i32 + h_first) as u32;
            let side_idx = self.get_index(row, target_col);
            if self.cells[side_idx] == Cell::Empty as u8 {
                self.cells[side_idx] = cell_u8;
                self.cells[idx] = Cell::Empty as u8;
                return;
            }
        }
        
        if (h_second == -1 && can_go_left) || (h_second == 1 && can_go_right) {
            let target_col = (col as i32 + h_second) as u32;
            let side_idx = self.get_index(row, target_col);
            if self.cells[side_idx] == Cell::Empty as u8 {
                self.cells[side_idx] = cell_u8;
                self.cells[idx] = Cell::Empty as u8;
                return;
            }
        }
    }
}
