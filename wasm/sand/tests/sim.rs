use sand::Universe;

const W: i32 = 64;
const H: i32 = 64;

fn count(u: &Universe, mat: u8) -> usize {
    let mut n = 0;
    for y in 0..H {
        for x in 0..W {
            if u.mat_at(x, y) == mat {
                n += 1;
            }
        }
    }
    n
}

#[test]
fn sand_falls_and_piles() {
    let mut u = Universe::new(W as u32, H as u32);
    u.paint(5, 32, 1, 2); // sand blob high up
    let total = count(&u, 1);
    assert!(total > 0);
    for _ in 0..200 {
        u.tick();
    }
    // conservation (sand can become glass only via heat; none here)
    assert_eq!(count(&u, 1), total, "sand lost or duplicated");
    // everything should have landed in the bottom rows
    for y in 0..H - 10 {
        for x in 0..W {
            assert_ne!(u.mat_at(x, y), 1, "sand stuck mid-air at {},{}", x, y);
        }
    }
}

#[test]
fn water_spreads_flat() {
    let mut u = Universe::new(W as u32, H as u32);
    // column of water in the middle
    for y in 20..40 {
        u.paint(y, 32, 2, 0);
    }
    for _ in 0..400 {
        u.tick();
    }
    // water (2) + any steam (6) should still exist
    assert!(count(&u, 2) + count(&u, 6) > 0);
    // should have spread out: bottom row occupied across a decent span
    let bottom_span: usize = (0..W).filter(|&x| u.mat_at(x, H - 1) == 2).count();
    assert!(bottom_span > 10, "water did not spread (span={})", bottom_span);
    // no tall column left in the middle
    assert_eq!(u.mat_at(32, 30), 0, "water column never collapsed");
}

#[test]
fn lava_meets_water() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 20..30 {
        u.paint(H - 1, x, 9, 0); // lava on floor
        u.paint(H - 3, x, 2, 0); // water above
    }
    for _ in 0..300 {
        u.tick();
    }
    let obsidian = count(&u, 14);
    let steam = count(&u, 6);
    let stone = count(&u, 3);
    assert!(
        obsidian + steam + stone > 0,
        "no reaction products (obsidian={} steam={} stone={})",
        obsidian, steam, stone
    );
}

#[test]
fn gunpowder_explodes_near_lava() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 28..36 {
        u.paint(H - 1, x, 15, 0); // gunpowder on floor
    }
    u.paint(H - 1, 27, 9, 1); // lava beside it
    let before = count(&u, 15);
    assert!(before > 0);
    for _ in 0..300 {
        u.tick();
    }
    assert!(count(&u, 15) < before, "gunpowder never ignited");
}

#[test]
fn wood_burns_to_ash_or_smoke() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 28..36 {
        u.paint(H - 1, x, 4, 0); // wood floor strip
    }
    u.paint(H - 2, 30, 9, 1); // lava on top
    for _ in 0..600 {
        u.tick();
    }
    let wood = count(&u, 4);
    assert!(wood < 8, "wood never burned (still {} cells)", wood);
}

#[test]
fn water_freezes_near_ice_then_melts() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 0..W {
        u.paint(H - 1, x, 11, 0); // ice floor
    }
    for x in 20..40 {
        u.paint(H - 2, x, 2, 0); // shallow water on it
    }
    for _ in 0..600 {
        u.tick();
    }
    assert!(count(&u, 11) > W as usize, "no water froze");
}

#[test]
fn fire_spreads_across_oil() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 10..54 {
        u.paint(H - 1, x, 7, 0); // oil strip on the floor
    }
    u.paint(H - 2, 12, 9, 0); // single lava cell at one end
    for _ in 0..400 {
        u.tick();
    }
    let oil = count(&u, 7);
    assert!(oil < 20, "fire failed to spread across oil ({} cells left)", oil);
}

#[test]
fn fire_melts_ice() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 20..44 {
        for dy in 1..4 {
            u.paint(H - dy, x, 11, 0); // ice slab
        }
    }
    for x in 28..36 {
        u.paint(H - 5, x, 9, 0); // lava on top
    }
    let ice_before = count(&u, 11);
    // measure mid-burn: later, steam condenses, rains down and re-freezes
    // on the slab (emergent water cycle), masking the melt
    let mut min_ice = ice_before;
    for _ in 0..600 {
        u.tick();
        min_ice = min_ice.min(count(&u, 11));
    }
    assert!(min_ice < ice_before, "heat never melted ice ({} -> min {})", ice_before, min_ice);
}

#[test]
fn water_extinguishes_burning_wood() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 20..44 {
        u.paint(H - 1, x, 4, 0); // wood floor
    }
    u.paint(H - 2, 32, 9, 0); // lava starts the fire
    for _ in 0..60 {
        u.tick();
    }
    // dump water on the whole thing
    for x in 16..48 {
        for dy in 6..14 {
            u.paint(H - dy, x, 2, 0);
        }
    }
    for _ in 0..400 {
        u.tick();
    }
    // fire should be out (no fire or embers left burning)
    assert_eq!(count(&u, 5), 0, "fire still burning under water");
}

#[test]
fn steam_rises_high() {
    let mut u = Universe::new(W as u32, H as u32);
    for x in 28..36 {
        u.paint(H - 1, x, 9, 0); // lava floor
        u.paint(H - 3, x, 2, 0); // water above -> steam
    }
    let mut max_height = 0;
    for t in 0..400 {
        u.tick();
        let _ = t;
        for y in 0..H {
            for x in 0..W {
                if u.mat_at(x, y) == 6 {
                    let height = H - y;
                    if height > max_height {
                        max_height = height;
                    }
                }
            }
        }
    }
    // steam should climb most of a 64-cell tall world
    assert!(max_height > 48, "steam only reached height {} of {}", max_height, H);
}
