# Optimization & Refinement Report

## Overview
This document summarizes the changes made to the particle background system (`main.js`) to improve its physics realism, visual quality, and performance efficiency.

## 1. Physics Refinements
-   **Gaussian Speed Distribution (S-Curve)**:
    -   replaced the hardcoded speed categories with a **Box-Muller Transform**.
    -   This generates a "Bell Curve" of speeds, creating a natural feel where most particles move at average speed, with rare slow and fast outliers.
-   **Opacity Reduction**:
    -   Reduced particle opacity to **0.4** (40%) to make the background less distracting.
-   **Delta-Time Movement**:
    -   Decoupled physics animation from the frame rate.
    -   Particles now move at a constant *real-world speed* regardless of correct FPS or lag.

## 2. Performance Optimizations
We addressed severe lag caused by the $N^2$ complexity of the particle system (100 particles = 10,000 interactions per frame).

### Phase 1: Rendering Efficiency
-   **Opacity Binning**:
    -   **Problem**: Drawing 1000+ lines individually with unique opacity levels forced thousands of draw calls per frame.
    -   **Solution**: Grouped lines into 10 "opacity bins".
    -   **Result**: Reduced draw calls from ~1000 to **10** per frame.

### Phase 2: Memory & Algorithms
-   **Zero-Allocation Pattern**:
    -   **Problem**: Creating new arrays every frame caused the Garbage Collector to pause execution (jitter).
    -   **Solution**: Switched to static, reusable arrays (`bins.length = 0`).
-   **Spatial Partitioning (Grid)**:
    -   **Problem**: Checking every point against every other point is O($N^2$).
    -   **Solution**: Implemented a spatial grid. Points only check neighbors in adjacent cells.
    -   **Result**: Complexity reduced to O(N). Computations dropped from **10,000** to **~500** per frame.

### Phase 3: Input Decoupling
-   **Problem**: The `mousemove` event triggered DOM updates potentially 1000 times/sec (high polling rate mice), causing "DOM Thrashing".
-   **Solution**: The event listener now only updates coordinate variables. The actual visual update happens once per frame in the animation loop.

## Known Issues
-   **Visibility**: User reported particles disappearing on some configurations despite verification.
-   **Complexity**: The code is significantly more complex than the original simple loop.

## Code Changes
All changes are located in `main.js`, specifically:
-   `initNodes`: Gaussian distribution logic.
-   `drawCircuit`: The main render loop containing the Grid, Binning, and Delta-Time logic.
-   `initGlobalListeners`: Throttled event handling.
