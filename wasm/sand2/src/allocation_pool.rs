//! Bounded reuse of small allocations in the single-threaded Wasm instance.
//! Contains no simulation rules; large allocations use the standard allocator.
use std::alloc::{GlobalAlloc, Layout, System};
use std::cell::UnsafeCell;
use std::ptr;

const CLASSES: usize = 7; // 16, 32, 64, 128, 256, 512, 1024 bytes.
struct PoolState { heads: [*mut u8; CLASSES], counts: [usize; CLASSES], large: [u64;32], large_bytes:u64 }
struct WasmPool(UnsafeCell<PoolState>);
// wasm32-wasip1 builds have no shared-memory/thread feature. Each browser
// worker owns its own module instance and this private allocator state.
unsafe impl Sync for WasmPool {}
impl WasmPool {
    const fn new() -> Self { Self(UnsafeCell::new(PoolState {heads: [ptr::null_mut(); CLASSES], counts: [0; CLASSES], large:[0;32], large_bytes:0})) }
    #[inline]
    fn class(layout: Layout) -> Option<usize> {
        if layout.align() > 16 || layout.size() > 1024 { return None; }
        Some(layout.size().max(16).next_power_of_two().trailing_zeros() as usize - 4)
    }
    #[inline]
    fn layout(class: usize) -> Layout {
        // Every class size is a positive multiple of this alignment.
        unsafe { Layout::from_size_align_unchecked(16 << class, 16) }
    }
}
unsafe impl GlobalAlloc for WasmPool {
    unsafe fn alloc(&self, layout: Layout) -> *mut u8 {
        unsafe {
            let Some(class) = Self::class(layout) else {
                let state = &mut *self.0.get();
                let bin = (usize::BITS-layout.size().max(1).leading_zeros()-1) as usize;
                state.large[bin] = state.large[bin].wrapping_add(1);
                state.large_bytes = state.large_bytes.wrapping_add(layout.size() as u64);
                return System.alloc(layout);
            };
            let state = &mut *self.0.get();
            let head = state.heads[class];
            if head.is_null() { return System.alloc(Self::layout(class)); }
            state.heads[class] = head.cast::<*mut u8>().read();
            state.counts[class] -= 1;
            head
        }
    }
    unsafe fn dealloc(&self, address: *mut u8, layout: Layout) {
        unsafe {
            let Some(class) = Self::class(layout) else { System.dealloc(address, layout); return; };
            let state = &mut *self.0.get();
            let limit = if class <= 3 { 4096 } else { 512 };
            if state.counts[class] >= limit { System.dealloc(address, Self::layout(class)); return; }
            address.cast::<*mut u8>().write(state.heads[class]);
            state.heads[class] = address;
            state.counts[class] += 1;
        }
    }
    unsafe fn realloc(&self, address: *mut u8, old: Layout, new_size: usize) -> *mut u8 {
        unsafe {
            let new = Layout::from_size_align_unchecked(new_size, old.align());
            if let Some(class) = Self::class(old) {
                if Self::class(new) == Some(class) { return address; }
            } else if Self::class(new).is_none() { return System.realloc(address, old, new_size); }
            let result = self.alloc(new);
            if !result.is_null() {
                ptr::copy_nonoverlapping(address, result, old.size().min(new_size));
                self.dealloc(address, old);
            }
            result
        }
    }
}
#[global_allocator]
static ALLOCATOR: WasmPool = WasmPool::new();

/// Exercise allocation contracts independently of the physics algorithms.
#[unsafe(no_mangle)]
pub extern "C" fn world_allocator_check() -> u32 {
    unsafe {
        for align in [1, 2, 4, 8, 16, 32, 64] {
            for size in [1, 3, 7, 15, 16, 17, 31, 32, 33, 63, 65, 127, 129, 255, 257, 511, 513, 1023, 1025, 4096] {
                let layout = Layout::from_size_align(size, align).unwrap();
                let memory = ALLOCATOR.alloc_zeroed(layout);
                if memory.is_null() || memory as usize % align != 0 { return 1; }
                if (0..size).any(|i| memory.add(i).read() != 0) { return 2; }
                for i in 0..size { memory.add(i).write((i % 251) as u8); }
                let grown_size = size*2+7;
                let grown = ALLOCATOR.realloc(memory, layout, grown_size);
                if grown.is_null() || grown as usize % align != 0 { return 3; }
                if (0..size).any(|i| grown.add(i).read() != (i % 251) as u8) { return 4; }
                let grown_layout = Layout::from_size_align(grown_size, align).unwrap();
                let shrunk = ALLOCATOR.realloc(grown, grown_layout, size);
                if shrunk.is_null() || shrunk as usize % align != 0 { return 5; }
                if (0..size).any(|i| shrunk.add(i).read() != (i % 251) as u8) { return 6; }
                ALLOCATOR.dealloc(shrunk, layout);
            }
        }
    }
    0
}

#[unsafe(no_mangle)]
pub extern "C" fn world_allocator_large_count(bin:u32) -> u64 { unsafe {(*ALLOCATOR.0.get()).large.get(bin as usize).copied().unwrap_or(0)} }
#[unsafe(no_mangle)]
pub extern "C" fn world_allocator_large_bytes() -> u64 { unsafe {(*ALLOCATOR.0.get()).large_bytes} }
