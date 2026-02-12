use meval::Expr;
use std::f64;
use wasm_bindgen::prelude::*;

#[wasm_bindgen(start)]
pub fn main_js() -> Result<(), JsValue> {
    console_error_panic_hook::set_once();
    Ok(())
}

#[wasm_bindgen]
pub struct PlotResult {
    lines: Vec<f64>,         // [x1, y1, x2, y2, ...]
    intersections: Vec<f64>, // [x, y, ...]
}

#[wasm_bindgen]
impl PlotResult {
    #[wasm_bindgen(constructor)]
    pub fn new() -> PlotResult {
        PlotResult {
            lines: Vec::new(),
            intersections: Vec::new(),
        }
    }

    pub fn get_lines(&self) -> Vec<f64> {
        self.lines.clone()
    }

    pub fn get_intersections(&self) -> Vec<f64> {
        self.intersections.clone()
    }
}

fn get_t(v1: f64, v2: f64) -> f64 {
    if (v2 - v1).abs() < 1e-9 {
        0.5
    } else {
        (0.0 - v1) / (v2 - v1)
    }
}

#[wasm_bindgen]
pub fn plot_equation(
    eq_str: &str,
    w: i32,
    h: i32,
    scale: f64,
    center_x: i32,
    center_y: i32,
    step: i32, // LOD Step
    collision_buffer: &mut [i8],
    eq_id: i8,
    _vars_names: Box<[JsValue]>, // List of variable names ["a", "b"]
    _vars_values: Box<[f64]>,    // List of values [1.0, -0.5]
) -> PlotResult {
    let mut result = PlotResult::new();

    let clean_eq = eq_str.to_string();

    let parts: Vec<&str> = clean_eq.split('=').collect();
    let expr_str = if parts.len() > 1 {
        format!("({}) - ({})", parts[0], parts[1])
    } else {
        parts[0].to_string()
    };

    let expr: Expr = match expr_str.parse() {
        Ok(e) => e,
        Err(_) => return result,
    };

    let func = match expr.bind2("x", "y") {
        Ok(f) => f,
        Err(_) => return result,
    };

    let step_f = step as f64;
    let grid_cols = (w / step) + 2;

    let mut current_row_vals: Vec<f64> = vec![0.0; grid_cols as usize];
    let mut next_row_vals: Vec<f64> = vec![0.0; grid_cols as usize];

    for i in 0..grid_cols {
        let px = i * step;
        let wx = (px - center_x) as f64 / scale;
        let wy = (center_y - 0) as f64 / scale;
        current_row_vals[i as usize] = func(wx, wy);
    }

    let mut py = 0;
    while py < h {
        let next_py = py + step;
        let wy_next = (center_y - next_py) as f64 / scale;
        for i in 0..grid_cols {
            let px = i * step;
            let wx = (px - center_x) as f64 / scale;
            next_row_vals[i as usize] = func(wx, wy_next);
        }

        let mut px = 0;
        let mut i = 0;
        while px < w {
            let tl = current_row_vals[i];
            let tr = current_row_vals[i + 1];
            let bl = next_row_vals[i];
            let br = next_row_vals[i + 1];

            if tl.is_nan() || tr.is_nan() || bl.is_nan() || br.is_nan() {
                px += step;
                i += 1;
                continue;
            }

            let mut case = 0;
            if tl > 0.0 {
                case |= 8;
            }
            if tr > 0.0 {
                case |= 4;
            }
            if br > 0.0 {
                case |= 2;
            }
            if bl > 0.0 {
                case |= 1;
            }

            if case != 0 && case != 15 {
                let off_top = get_t(tl, tr) * step_f;
                let off_right = get_t(tr, br) * step_f;
                let off_bottom = get_t(bl, br) * step_f;
                let off_left = get_t(tl, bl) * step_f;

                let p_top_x = px as f64 + off_top;
                let p_top_y = py as f64;

                let p_right_x = px as f64 + step_f;
                let p_right_y = py as f64 + off_right;

                let p_bottom_x = px as f64 + off_bottom;
                let p_bottom_y = py as f64 + step_f;

                let p_left_x = px as f64;
                let p_left_y = py as f64 + off_left;

                match case {
                    1 => push_line(
                        &mut result.lines,
                        p_left_x,
                        p_left_y,
                        p_bottom_x,
                        p_bottom_y,
                    ),
                    2 => push_line(
                        &mut result.lines,
                        p_bottom_x,
                        p_bottom_y,
                        p_right_x,
                        p_right_y,
                    ),
                    3 => push_line(&mut result.lines, p_left_x, p_left_y, p_right_x, p_right_y),
                    4 => push_line(&mut result.lines, p_top_x, p_top_y, p_right_x, p_right_y),
                    5 => {
                        push_line(&mut result.lines, p_left_x, p_left_y, p_top_x, p_top_y);
                        push_line(
                            &mut result.lines,
                            p_bottom_x,
                            p_bottom_y,
                            p_right_x,
                            p_right_y,
                        );
                    }
                    6 => push_line(&mut result.lines, p_top_x, p_top_y, p_bottom_x, p_bottom_y),
                    7 => push_line(&mut result.lines, p_left_x, p_left_y, p_top_x, p_top_y),
                    8 => push_line(&mut result.lines, p_left_x, p_left_y, p_top_x, p_top_y),
                    9 => push_line(&mut result.lines, p_top_x, p_top_y, p_bottom_x, p_bottom_y),
                    10 => {
                        push_line(
                            &mut result.lines,
                            p_left_x,
                            p_left_y,
                            p_bottom_x,
                            p_bottom_y,
                        );
                        push_line(&mut result.lines, p_top_x, p_top_y, p_right_x, p_right_y);
                    }
                    11 => push_line(&mut result.lines, p_top_x, p_top_y, p_right_x, p_right_y),
                    12 => push_line(&mut result.lines, p_left_x, p_left_y, p_right_x, p_right_y),
                    13 => push_line(
                        &mut result.lines,
                        p_bottom_x,
                        p_bottom_y,
                        p_right_x,
                        p_right_y,
                    ),
                    14 => push_line(
                        &mut result.lines,
                        p_left_x,
                        p_left_y,
                        p_bottom_x,
                        p_bottom_y,
                    ),
                    _ => {}
                }

                let center_px = px + (step / 2);
                let center_py = py + (step / 2);
                let idx = (center_py * w + center_px) as usize;

                if idx < collision_buffer.len() {
                    let existing = collision_buffer[idx];
                    if existing != 0 && existing != eq_id {
                        result.intersections.push(center_px as f64);
                        result.intersections.push(center_py as f64);
                    }
                    collision_buffer[idx] = eq_id;
                }
            }

            px += step;
            i += 1;
        }

        current_row_vals.copy_from_slice(&next_row_vals);
        py += step;
    }

    result
}

fn push_line(lines: &mut Vec<f64>, x1: f64, y1: f64, x2: f64, y2: f64) {
    lines.push(x1);
    lines.push(y1);
    lines.push(x2);
    lines.push(y2);
}
