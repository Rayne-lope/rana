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

## 3.5. Arsitektur & Filosofi Preset (Preset Philosophy & Architecture)

### 1. Preset Bukan Sekadar Filter (Preset ≠ LUT, Preset = Recipe)
Preset pada Rana tidak boleh dianggap hanya sebagai file LUT warna (Look-Up Table). Preset dirancang sebagai sebuah **Recipe** (Resep) yang merupakan kombinasi dari parameter visual dan perilaku grafis yang kompleks.

Setiap preset didefinisikan sebagai kombinasi dari:
- **Color Parameters** (Pengaturan warna dasar seperti temperature, tint, contrast, dll.)
- **Tone Curve** (Kurva nada warna)
- **Grain Settings** (Intensitas dan ukuran grain film)
- **Vignette Settings** (Intensitas vignette sudut gambar)
- **LUT** (Look-Up Table warna 2D/3D opsional)
- **Overlay** (Aset PNG leak/dust/frame opsional)
- **Effects** (Efek tambahan seperti halation/bloom opsional)
- **Randomization Behaviors** (Perilaku acak masa depan per foto)

```
Preset
├── Color Parameters
├── Grain
├── Vignette
├── LUT (optional)
├── Overlay (optional)
└── Effects (optional)
```

### 2. Preset Layers (Arsitektur Berlapis)
Untuk mempermudah ekspansi tanpa harus mengubah arsitektur inti engine di masa mendatang, preset dibagi menjadi tiga lapisan:

- **Layer 1 — Parameter Layer**: Pengaturan parameter warna dasar (temperature, tint, saturation, contrast, fade, grain, vignette). Didukung mulai dari Phase 3.
- **Layer 2 — Asset Layer**: Berkas pendukung seperti file LUT, light leak overlays, dust overlays, dan frames. Diperkenalkan pada Phase 4–5.
- **Layer 3 — Behavior Layer**: Perilaku acak (random grain seed, random light leak selection, random dust variation, dan preset-specific randomness). Diperkenalkan pada Phase 7+.

Arsitektur berlapis ini memisahkan logika dasar (Engine) dengan data (Preset Recipes & Assets) sehingga penambahan preset baru di kemudian hari tidak memerlukan refaktorisasi kode program.

### 3. Skema Preset (Preset Schema)
Skema JSON preset masa depan yang extensible dirancang sebagai berikut:

```json
{
  "id": "rana_warm",
  "name": "Rana Warm",
  "category": "Classic",
  "color": {
    "temperature": 0.2,
    "contrast": 0.1,
    "saturation": 0.15
  },
  "grain": {
    "intensity": 0.1
  },
  "vignette": {
    "intensity": 0.05
  },
  "lut": null,
  "overlay": null,
  "behavior": null
}
```
Skema ini dapat dikembangkan di fase-fase berikutnya dengan menambahkan objek baru (misal: `"lut": "assets/luts/classic1.png"`, `"behavior": { "random_leak": true }`) tanpa merusak parser engine yang sudah ada.

### 4. Strategi Preset Jangka Panjang (Long-Term Preset Strategy)
Rana dirancang untuk mendukung preset analog legendaris seperti:
- Kodak Gold
- Kodak Portra
- Fuji 400H
- Cinestill 800T
- Gaya Disposable Camera
- Gaya Y2K Camera

Dukungan preset ini akan dicapai secara dinamis melalui kombinasi **Preset Engine**, **LUTs**, **Overlay Assets**, dan **Randomization Systems** tanpa mengubah kode arsitektur inti. Roadmap pengembangan Rana sengaja memisahkan antara **Engine Development** (pembuatan mesin rendering dan parser) dan **Preset Content Creation** (pembuatan resep preset dan aset grafis).

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
Memvalidasi keandalan dan stabilitas shader pipeline (membuktikan bahwa alur Camera → Shader → Realtime Preview berjalan andal tanpa lag).

## Deliverables
- Realtime preview dengan shader parameter-based.
- Hanya 3 preset parameter-based dasar: **Rana Warm**, **Rana Cool**, dan **Rana Mono**.
- Mekanisme switching preset tanpa restart kamera.
- (Tidak ada dukungan LUT, tidak ada emulasi film kompleks, tidak ada preset Kodak/Fuji di fase ini).

## Recommended Stack
- OpenGL ES / shader pipeline di native Android.
- Flutter tetap sebagai controller UI.

## Presets for This Phase
- **Rana Warm**: Shader-parameter berdasarkan penyesuaian temperature (peningkatan merah/kuning).
- **Rana Cool**: Shader-parameter berdasarkan penyesuaian tint/temperature (peningkatan biru).
- **Rana Mono**: Shader-parameter berdasarkan desaturasi penuh (luminance formula).

## Tasks
1. Render frame kamera ke GPU texture.
2. Implementasi fragment shader parameter-based untuk 3 preset standar.
3. Tambahkan preset switching tanpa restart camera.
4. Sinkronkan parameter preview dengan state Flutter.
5. Buat fallback jika device lemah.
6. Pastikan FPS tetap stabil.
7. Buat mekanisme enable/disable efek.
8. Optimalkan agar preview tidak delay.

## Acceptance Criteria
- Preview terfilter realtime.
- Pergantian antara 3 preset (Rana Warm, Rana Cool, Rana Mono) cepat dan tanpa lag.
- FPS stabil di kisaran 24-30 FPS.
- Hasil preview tidak patah-patah.

## Difficulty
**Hard**

## Frontier Model Priority
**High**

## Why
Membuktikan keandalan dasar rendering pipeline EGL context dan GLSL shader thread.

---

# Phase 3 — Preset Engine V1

## Objective
Membangun arsitektur preset engine yang scalable agar dapat mendukung preset gaya Dazz Cam di masa mendatang tanpa memerlukan refaktorisasi kode program. Fokus pada mesin parser/config generator, bukan kuantitas preset.

## Deliverables
- Preset schema & parser (JSON-based configuration).
- Dynamic preset loading & registration dari folder assets.
- Preset metadata & categories.
- Preset thumbnail generation system.
- (Belum ada dukungan LUT di fase ini).

## Tasks
1. Buat model data preset extensible berbasis JSON.
2. Implementasi parser JSON di Flutter dan native bridge untuk dynamic preset registration (mendukung Layer 1 - Parameter Layer).
3. Rancang UI selector preset dinamis berdasarkan resep JSON yang dimuat secara runtime.
4. Rancang preset categories (misal: Classic, Disposable, Retro).
5. Siapkan dynamic thumbnail generator.
6. Buat preset preview carousel dinamis.

## Acceptance Criteria
- Preset baru dapat ditambahkan hanya dengan menambahkan JSON recipe + aset tanpa memodifikasi kode engine.
- Loading preset stabil dan cepat.
- JSON ter-parse dengan benar tanpa merusak sistem.

## Difficulty
**Hard**

## Frontier Model Priority
**High**

## Why
Fase ini menentukan fondasi arsitektur database/konfigurasi preset yang scalable untuk semua preset masa depan.

---

# Phase 4 — Capture Processing & High-Resolution Export (with LUT Support)

## Objective
Saat foto diambil, hasil akhir harus diproses dengan kualitas tinggi dan konsisten dengan preview, serta memperkenalkan integrasi LUT warna untuk pertama kalinya.

## Deliverables
- Processing screen / progress state.
- Apply shader to captured image.
- High-resolution output.
- **First-time 2D/3D LUT Support** in the rendering pipeline (Layer 2).
- Save final image & Gallery save flow.

## Rationale for LUT in Phase 4
> [!NOTE]
> Dukungan LUT sengaja dipindahkan ke Phase 4 agar rendering pipeline (EGL & custom shader) benar-benar terbukti stabil dan andal terlebih dahulu pada Phase 2 & 3 sebelum kompleksitas color mapping LUT ditambahkan.

## Effects to Include
- Color grade (LUT-based).
- Basic Parameter adjustments (Layer 1).
- Grain.
- Date stamp.
- Vignette.

## Tasks
1. Ambil frame resolusi tinggi.
2. Implementasi EGL texture rendering untuk binding LUT (.png) ke fragment shader.
3. Jalankan high-resolution processing pipeline dengan LUT + parameter.
4. Pastikan memory tidak leak atau OOM saat memproses gambar besar.
5. Implement progress/loading state.
6. Simpan output ke gallery via MediaStore.
7. Tampilkan preview hasil.
8. Handle low-memory condition.

## Acceptance Criteria
- Foto tinggi resolusi berhasil diproses menggunakan shader + LUT dan tersimpan.
- Hasil final konsisten secara visual dengan preview.
- Tidak ada OOM saat capture besar.

## Difficulty
**Very Hard**

## Frontier Model Priority
**Very High**

## Why
Mengintegrasikan pengolahan resolusi tinggi dan binding LUT tekstur yang efisien di GPU.

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
1. **Phase 2 — Live Preview Effect Pipeline**
2. **Phase 3 — Preset Engine Architecture**
3. **Phase 4 — High-Resolution Export & LUT Support**
4. **Phase 7 — Advanced Analog Effects**
5. **Phase 10 — Video Recording**

### Medium model or general agent can handle:
1. Phase 0 — Foundation
2. Phase 1 — Basic Camera Capture
3. Phase 5 — Core Analog Effects
4. Phase 6 — Gallery & Sharing
5. Phase 8 — Performance & Device Tuning
6. Phase 9 — Monetization structure

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

