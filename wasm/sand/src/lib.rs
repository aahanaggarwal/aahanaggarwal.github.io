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

#[wasm_bindgen]
pub struct Universe {
    width: u32,
    height: u32,
    cells: Vec<u8>,
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
        for row in (0..self.height - 1).rev() {
            for col in 0..self.width {
                let idx = self.get_index(row, col);
                let cell = self.cells[idx];
                
                if cell == Cell::Empty as u8 {
                    continue;
                }

                if cell == Cell::Stone as u8 || cell == Cell::Wood as u8 || cell == Cell::Plant as u8 {
                    continue;
                }

                let below_idx = self.get_index(row + 1, col);
                
                if self.cells[below_idx] == Cell::Empty as u8 {
                    self.cells[below_idx] = cell;
                    self.cells[idx] = Cell::Empty as u8;
                } else {
                    let mut moved = false;
                    if col > 0 {
                        let down_left_idx = self.get_index(row + 1, col - 1);
                        if self.cells[down_left_idx] == Cell::Empty as u8 {
                            self.cells[down_left_idx] = cell;
                            self.cells[idx] = Cell::Empty as u8;
                            moved = true;
                        }
                    }
                    
                    if !moved && col < self.width - 1 {
                        let down_right_idx = self.get_index(row + 1, col + 1);
                        if self.cells[down_right_idx] == Cell::Empty as u8 {
                            self.cells[down_right_idx] = cell;
                            self.cells[idx] = Cell::Empty as u8;
                        }
                    }
                }
            }
        }
    }

    pub fn paint(&mut self, row: u32, col: u32, color_val: u8, radius: i32) {
        let r_squared = radius * radius;
        
        for r in -radius..=radius {
            for c in -radius..=radius {
                if r*r + c*c <= r_squared {
                    let target_row = (row as i32 + r) as u32;
                    let target_col = (col as i32 + c) as u32;
                    
                    if target_row < self.height && target_col < self.width {
                        let idx = self.get_index(target_row, target_col);
                        // Only paint if empty or overwriting with a different non-empty color
                        // Actually better to just force paint for sandbox feel
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

impl Universe {
    fn get_index(&self, row: u32, col: u32) -> usize {
        (row * self.width + col) as usize
    }
}
