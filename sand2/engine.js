// Browser host for Lungo's supported WASI target. No directories, environment
// variables, sockets or input streams are exposed to the module.
let compiledModule;
export async function loadEngine() {
  compiledModule ??= (async () => {
    const response = await fetch(new URL('./pkg/sand2.wasm', import.meta.url));
    if (!response.ok) throw new Error(`Physics module: HTTP ${response.status}`);
    return WebAssembly.compile(await response.arrayBuffer());
  })().catch(error => { compiledModule = undefined; throw error; });
  const module = await compiledModule;
  let api;
  const view = () => new DataView(api.memory.buffer);
  const badFile = () => 8; // WASI EBADF; there are no preopened directories.
  const wasi = {
    random_get(pointer, length) {
      pointer >>>= 0; length >>>= 0;
      for (let offset = 0; offset < length; offset += 65536) {
        crypto.getRandomValues(new Uint8Array(api.memory.buffer, pointer + offset, Math.min(65536, length - offset)));
      }
      return 0;
    },
    environ_sizes_get(count, size) { count >>>= 0; size >>>= 0; view().setUint32(count, 0, true); view().setUint32(size, 0, true); return 0; },
    environ_get() { return 0; },
    fd_close: badFile,
    fd_prestat_get: badFile,
    fd_prestat_dir_name: badFile,
    fd_read: badFile,
    fd_seek: () => 29, // ESPIPE
    fd_fdstat_get(fd, pointer) {
      pointer >>>= 0;
      if (fd !== 1 && fd !== 2) return 8;
      new Uint8Array(api.memory.buffer, pointer, 24).fill(0);
      view().setUint8(pointer, 2); // Character device: stdout/stderr only.
      return 0;
    },
    fd_write(fd, vectors, count, written) {
      vectors >>>= 0; count >>>= 0; written >>>= 0;
      if (fd !== 1 && fd !== 2) return 8;
      let total = 0;
      let message = '';
      const data = view();
      const decoder = new TextDecoder();
      for (let i = 0; i < count; i++) {
        const pointer = data.getUint32(vectors + i * 8, true);
        const size = data.getUint32(vectors + i * 8 + 4, true);
        message += decoder.decode(new Uint8Array(api.memory.buffer, pointer, size), {stream: true});
        total += size;
      }
      data.setUint32(written, total, true);
      if (message.trim()) (fd === 2 ? console.error : console.info)(message.trim());
      return 0;
    },
    proc_exit(code) { throw new Error(`Physics module exited (${code})`); },
  };
  // Reject newly introduced capabilities instead of silently granting them.
  for (const entry of WebAssembly.Module.imports(module)) {
    if (entry.module !== 'wasi_snapshot_preview1' || !(entry.name in wasi)) {
      throw new Error(`Unsupported physics import: ${entry.module}.${entry.name}`);
    }
  }
  const instance = await WebAssembly.instantiate(module, {wasi_snapshot_preview1: wasi});
  api = instance.exports;
  api._initialize?.();
  // Wasm i32 results are signed JS numbers even for Rust u32 pointers.
  // Normalize once at the ABI boundary, including addresses above 2 GiB.
  const result = {...api};
  for (const name of ['world_pixels', 'world_audit', 'world_catalogue', 'world_inspect', 'world_oracle']) {
    result[name] = (...args) => api[name](...args) >>> 0;
  }
  return result;
}
