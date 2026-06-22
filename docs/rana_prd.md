# PRD — Rana

## 1. Ringkasan Produk

**Nama produk:** Rana  
**Kategori:** Android camera app dengan vibe retro / film / disposable / vintage photography.  
**Target utama:** user yang suka foto estetik, analog look, dan hasil cepat tanpa edit rumit.  
**Strategi produk:** fokus ke **foto terlebih dahulu**, video ditunda ke fase lanjut.

### Value Proposition
Rana adalah kamera Android yang memberi pengalaman foto retro dengan preview live, preset film, grain, light leak, date stamp, dan proses capture yang terasa seperti kamera analog, tetapi tetap praktis untuk pengguna modern.

### Prinsip Produk
1. **Simple first** — buka app langsung ke kamera.
2. **Realtime feel** — user melihat efek sebelum memotret.
3. **Offline by default** — semua proses on-device.
4. **Fast capture** — tidak mengorbankan UX demi efek.
5. **Phase-based delivery** — fitur kompleks dipisah agar MVP bisa cepat rilis.

---

## 2. Goals

### Product Goals
- Membuat app foto retro yang stabil di Android.
- Menyediakan preview filter realtime yang terasa halus.
- Menyediakan output foto yang sama atau sangat dekat dengan preview.
- Menjadi basis untuk pengembangan filter pack dan efek lanjutan.

### Technical Goals
- Kamera preview stabil di banyak device.
- Rendering efek menggunakan GPU pipeline, bukan CPU bitmap processing.
- Export image resolusi tinggi dengan kualitas konsisten.
- Struktur kode modular agar mudah dikembangkan AI agent.

### Business Goals
- MVP cepat selesai.
- Fitur dasar cukup kuat untuk dipakai user nyata.
- Fondasi cukup fleksibel untuk monetisasi preset pack atau premium features nanti.

---

## 3. Non-Goals untuk MVP Awal

Fitur berikut **tidak masuk fase awal**:
- Video recording.
- Double exposure.
- Cloud sync.
- Social sharing platform internal.
- Login akun.
- AI enhancement.
- Editing timeline.
- Advanced manual camera controls.

---

## 4. Product Scope per Phase

# Phase 0 — Foundation / Setup

## Objective
Membangun pondasi project supaya semua phase berikutnya tidak berantakan.

## Deliverables
- Flutter project setup.
- Native Android module / plugin architecture jika dibutuhkan.
- Navigasi dasar.
- Design system dasar.
- State management.
- Asset pipeline.
- Folder structure.
- Logging dan error handling.
- Permission flow dasar.
- Stub untuk camera screen, preview screen, result screen.

## Tech Decisions
### Frontend
- Flutter untuk UI utama.
- Navigation: `go_router`.
- State management: `Riverpod` atau `Bloc`.
- Asset management: folder preset, overlay, stamp, icon.

### Native Bridge
- Untuk kamera realtime dan shader, siapkan Android native layer.
- Flutter berperan sebagai shell UI, bukan engine kamera utama.

### Architecture
- Modular feature-first structure.
- Pisahkan UI, state, service, dan native bridge.

## Tasks
1. Buat struktur project Flutter.
2. Buat route untuk splash, home/camera, gallery, settings.
3. Buat theme system: colors, typography, spacing.
4. Siapkan placeholder UI untuk camera screen.
5. Siapkan channel komunikasi Flutter ↔ Android native.
6. Siapkan permission flow untuk camera, storage, photos.
7. Siapkan logging, crash guard, dan error state UI.
8. Siapkan asset folder untuk LUT, overlay, stamp, ikon.
9. Buat kontrak data untuk filter preset.
10. Siapkan mock model untuk camera state.

## Acceptance Criteria
- App bisa dibuka dan masuk ke halaman kamera placeholder.
- Routing stabil.
- Theme konsisten.
- Native bridge berhasil dipanggil dari Flutter.
- Permission flow jalan tanpa crash.

## Difficulty
**Medium**

## Frontier Model Priority
**Low**

## Notes
Phase ini penting, tapi bukan bagian paling sulit. AI agent biasa cukup untuk setup dan scaffolding.

---

# Phase 1 — Basic Camera Capture

## Objective
Membuat kamera dasar yang bisa mengambil foto dan menyimpan hasil tanpa efek kompleks.

## Deliverables
- Live camera preview.
- Switch front/back camera.
- Capture photo.
- Save ke gallery.
- Basic flash toggle jika device mendukung.
- Preview hasil foto sederhana.

## Recommended Stack
- Android native camera layer: **CameraX**.
- Flutter hanya untuk UI overlay.
- Storage: MediaStore.

## Tasks
1. Integrasikan CameraX preview.
2. Sambungkan preview ke tampilan Flutter atau native view host.
3. Implement capture photo.
4. Simpan file ke gallery.
5. Tampilkan preview hasil capture.
6. Handle permission denied / revoked.
7. Handle lifecycle pause/resume.
8. Handle rotation / orientation.
9. Handle front camera mirroring.
10. Uji di minimal 3 device.

## Acceptance Criteria
- Preview kamera tampil stabil.
- Foto berhasil diambil dan tersimpan.
- Tidak ada crash saat switch app atau rotate.
- Front/back camera bisa diganti.

## Difficulty
**Medium**

## Frontier Model Priority
**Medium**

## Why
Masih cukup bisa dikerjakan AI biasa, tapi integrasi camera lifecycle dan device compatibility sering butuh debugging yang rapi.

---

# Phase 2 — Live Preview Effect Pipeline

## Objective
Membuat efek visual realtime pada preview kamera.

## Deliverables
- Realtime filter preview.
- Shader pipeline dasar.
- Preset switching di preview.
- Overlay ringan seperti vignette atau frame.

## Recommended Stack
- OpenGL ES / shader pipeline di native Android.
- Flutter tetap sebagai controller UI.

## Effects for This Phase
- Warm tone.
- Cool tone.
- Black & white.
- Slight vignette.
- Grain ringan.

## Tasks
1. Render frame kamera ke GPU texture.
2. Apply fragment shader untuk warna dasar.
3. Tambahkan preset switching tanpa restart camera.
4. Sinkronkan preview dengan state Flutter.
5. Buat fallback jika device lemah.
6. Pastikan FPS tetap stabil.
7. Buat mekanisme enable/disable efek.
8. Optimalkan agar preview tidak delay.

## Acceptance Criteria
- Filter terlihat realtime.
- Pergantian preset cepat.
- FPS masih nyaman dipakai.
- Hasil preview tidak patah-patah.

## Difficulty
**Hard**

## Frontier Model Priority
**High**

## Why
Bagian ini mulai masuk ranah shader, texture pipeline, dan performa GPU. Ini titik awal yang layak ditangani model kuat.

---

# Phase 3 — Film Preset System

## Objective
Membangun sistem preset film yang mudah ditambah dan diatur.

## Deliverables
- Daftar preset film.
- Metadata preset.
- Thumbnail preset.
- Preset lock/unlock structure.
- Preset category system.

## Example Preset Categories
- Classic film.
- Disposable camera.
- Warm retro.
- Cold retro.
- Night film.
- B&W.

## Tasks
1. Buat model data preset.
2. Buat asset naming convention.
3. Buat UI selector preset.
4. Buat mapping preset → shader params.
5. Siapkan thumbnail generator.
6. Buat preset preview carousel.
7. Siapkan sistem add preset baru tanpa ubah arsitektur inti.

## Acceptance Criteria
- User bisa pilih preset dengan cepat.
- Struktur preset rapi dan scalable.
- Menambah preset baru tidak merusak sistem.

## Difficulty
**Medium**

## Frontier Model Priority
**Low to Medium**

## Why
Ini lebih banyak product organization dan asset management daripada algoritma berat.

---

# Phase 4 — Capture Processing & High-Resolution Export

## Objective
Saat foto diambil, hasil akhir harus diproses dengan kualitas tinggi dan konsisten dengan preview.

## Deliverables
- Processing screen / progress state.
- Apply shader or equivalent processing to captured image.
- High-resolution output.
- Save final image.
- Retake / share / save flow.

## Important Requirement
Preview dan hasil capture harus sedekat mungkin agar user tidak merasa tertipu.

## Effects to Include
- Color grade.
- Grain.
- Light leak overlay.
- Dust/scratch overlay.
- Date stamp.
- Vignette.
- Optional chromatic aberration ringan.

## Tasks
1. Ambil frame resolusi tinggi.
2. Jalankan processing pipeline.
3. Pastikan memory tidak jebol.
4. Implement progress/loading state.
5. Simpan output ke gallery.
6. Tampilkan preview hasil.
7. Tambahkan retry jika processing gagal.
8. Handle low-memory condition.

## Acceptance Criteria
- Foto tinggi resolusi berhasil tersimpan.
- Hasil final masih sesuai karakter filter.
- Tidak OOM saat capture besar.

## Difficulty
**Very Hard**

## Frontier Model Priority
**Very High**

## Why
Ini bagian yang rawan paling banyak bug: memory, quality, consistency, and speed. Sangat cocok untuk frontier model.

---

# Phase 5 — Core Analog Effects

## Objective
Menambahkan efek khas kamera film yang membuat Rana terasa lebih hidup.

## Deliverables
- Grain.
- Light leak.
- Dust and scratches.
- Date stamp.
- Subtle bloom / halation.
- Lens distortion ringan.

## Tasks
1. Implement grain pattern yang tidak terlihat statis.
2. Implement overlay light leak random.
3. Implement dust/scratch texture overlay.
4. Implement date stamp style.
5. Implement bloom/halation ringan.
6. Implement lens distortion minimal.
7. Tambahkan intensity control.
8. Kombinasikan efek dalam urutan yang efisien.

## Acceptance Criteria
- Efek terasa analog, bukan sekadar filter biasa.
- Efek tidak terlalu berat.
- Preview tetap lancar.

## Difficulty
**Hard**

## Frontier Model Priority
**High**

## Why
Secara visual keliatan simple, tapi butuh tuning bagus supaya tidak fake. Halation dan bloom lebih sulit karena multi-pass rendering.

---

# Phase 6 — Gallery, History, and Sharing

## Objective
Memberi user tempat melihat hasil foto, favorit, dan share cepat.

## Deliverables
- Gallery screen.
- Recent captures.
- Detail view.
- Share action.
- Delete action.
- Favorite action (optional).

## Tasks
1. Baca file dari MediaStore.
2. Tampilkan grid gallery.
3. Buat detail viewer.
4. Tambahkan share intent.
5. Tambahkan delete flow.
6. Tambahkan state empty / loading / permission denied.

## Acceptance Criteria
- User bisa lihat hasil foto di dalam app.
- User bisa share foto tanpa keluar flow terlalu jauh.

## Difficulty
**Medium**

## Frontier Model Priority
**Low**

## Why
Bukan area paling kompleks, lebih ke UX dan storage integration.

---

# Phase 7 — Advanced Effects

## Objective
Menambahkan efek tingkat lanjut yang meningkatkan diferensiasi produk.

## Deliverables
- Double exposure.
- Multiple light leak styles.
- Film flash simulation.
- Randomized frame behavior.
- Preset-specific quirks.

## Tasks
1. Buat mekanisme blend dua frame.
2. Buat exposure stacking.
3. Tambahkan film flash effect.
4. Tambahkan random variation per shot.
5. Buat preset-specific parameter set.
6. Pastikan efek tetap bisa dimatikan.

## Acceptance Criteria
- Efek advanced terasa premium.
- Tidak merusak flow capture dasar.

## Difficulty
**Very Hard**

## Frontier Model Priority
**Very High**

## Why
Double exposure dan compositing bisa rumit karena butuh kontrol frame, timing, dan visual consistency.

---

# Phase 8 — Performance, Compatibility, and Device Tuning

## Objective
Memastikan app enak dipakai di banyak device Android.

## Deliverables
- Profiling performa.
- Device fallback behavior.
- Quality mode low/medium/high.
- Crash-safe state recovery.
- Thermal-safe behavior.

## Tasks
1. Uji di low-end, mid-range, flagship.
2. Uji front/back camera.
3. Uji rotation.
4. Uji orientation lock.
5. Uji memory pressure.
6. Uji preview FPS.
7. Uji export waktu proses.
8. Kurangi shader cost bila device lemah.
9. Buat fallback preset ringan.
10. Audit permission and lifecycle edge cases.

## Acceptance Criteria
- App stabil di banyak device.
- Filter berat punya fallback.
- Tidak gampang crash saat pindah app / rotate.

## Difficulty
**Hard**

## Frontier Model Priority
**High**

## Why
Fragmentasi Android sering jadi sumber bug paling besar.

---

# Phase 9 — Monetization / Premium Structure (Optional)

## Objective
Mempersiapkan struktur bisnis tanpa merusak UX.

## Deliverables
- Free preset.
- Premium preset pack.
- Unlock system.
- Minimal intrusive monetization.

## Tasks
1. Tentukan preset mana yang gratis.
2. Tentukan preset premium.
3. Buat premium flag system.
4. Buat UX gating yang tidak mengganggu.

## Difficulty
**Low to Medium**

## Frontier Model Priority
**Low**

---

# Phase 10 — Video Recording (Belakangan)

## Objective
Menambahkan video setelah foto sudah stabil.

## Deliverables
- Video record preview.
- Filtered video export.
- Audio sync.
- MP4 output.

## Tasks
1. Integrasi encode pipeline.
2. Sync camera frame ke encoder.
3. Test thermal behavior.
4. Test bitrate / resolution options.
5. Tuning performa.

## Difficulty
**Very Hard**

## Frontier Model Priority
**Very High**

## Why
Video + realtime filter + encode adalah kombinasi paling berat.

---

## 5. Recommended Prioritization for AI Agents

### Frontline frontier model should handle:
1. **Phase 4 — High-Resolution Export & Capture Processing**
2. **Phase 7 — Advanced Effects**
3. **Phase 10 — Video Recording**
4. **Phase 8 — Performance & Device Tuning**
5. **Phase 2 — Live Preview Effect Pipeline**

### Medium model or general agent can handle:
1. Phase 0 — Foundation
2. Phase 1 — Basic Camera Capture
3. Phase 3 — Film Preset System
4. Phase 6 — Gallery & Sharing
5. Phase 9 — Monetization structure

---

## 6. Suggested MVP Definition

### MVP v1 for Rana
- Flutter shell.
- Native camera preview.
- 5 film presets.
- Realtime filter preview.
- Capture photo.
- High-res save.
- Grain.
- Light leak.
- Date stamp.
- Gallery preview.

### Not in MVP v1
- Video.
- Double exposure.
- Complex bloom.
- Cloud sync.
- Login.

---

## 7. Suggested Tech Stack

### App Layer
- Flutter
- go_router
- Riverpod / Bloc

### Native Android Layer
- CameraX
- OpenGL ES
- MediaStore
- MediaCodec later
- Kotlin for bridge/plugin code

### Data & Assets
- LUT textures
- Overlay PNG assets
- JSON preset metadata

### Architecture Style
- Feature-first modular structure
- Flutter UI as shell
- Native rendering/camera engine under it

---

## 8. Final Product Direction

Rana should feel like:
- fast to open,
- simple to use,
- visually distinctive,
- film-inspired,
- and stable on real Android devices.

The highest-risk technical areas are the ones that need frontier-level assistance:
- realtime shader pipeline,
- high-res export consistency,
- advanced analog effects,
- and video later.

