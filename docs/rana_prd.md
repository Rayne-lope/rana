# PRD — Rana

## 1. Ringkasan Produk

**Nama produk:** Rana  
**Kategori:** Android camera app dengan vibe retro / film / disposable / vintage photography.  
**Target utama:** user yang suka foto estetik, analog look, dan hasil cepat tanpa edit rumit.  
**Strategi produk:** fokus ke **foto terlebih dahulu**, video ditunda ke fase lanjut.

### Value Proposition
Rana adalah kamera Android yang memberi pengalaman foto retro dengan preview live, preset film, grain, light leak, date stamp, dan proses capture yang terasa seperti kamera analog, tetapi tetap praktis untuk pengguna modern.

Mulai Phase 6, Rana mengembangkan **Rana Styles** — sebuah sistem adjustment visual yang diinspirasi oleh Apple Photographic Styles, memungkinkan pengguna membentuk mood foto mereka tanpa perlu memahami parameter teknis kamera.

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
- **[Phase 6+]** Memungkinkan pengguna menyesuaikan visual look secara personal tanpa editor profesional.

### Technical Goals
- Kamera preview stabil di banyak device.
- Rendering efek menggunakan GPU pipeline, bukan CPU bitmap processing.
- Export image resolusi tinggi dengan kualitas konsisten.
- Struktur kode modular agar mudah dikembangkan AI agent.
- **[Phase 6+]** Style parameters diteruskan sebagai shader uniforms sehingga tidak ada camera restart saat adjustment.

### Business Goals
- MVP cepat selesai.
- Fitur dasar cukup kuat untuk dipakai user nyata.
- Fondasi cukup fleksibel untuk monetisasi preset pack atau premium features nanti.
- **[Phase 6+]** Rana Styles menjadi diferensiator produk utama di pasar kamera retro Android.

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
- **Texture Settings** (Intensitas dan karakter grain/dust film — user-facing label: **Texture**)
- **Vignette Settings** (Intensitas vignette sudut gambar)
- **LUT** (Look-Up Table warna 2D/3D opsional)
- **Overlay** (Aset PNG leak/dust/frame opsional)
- **Effects** (Efek tambahan seperti halation/bloom opsional)
- **Randomization Behaviors** (Perilaku acak masa depan per foto)

> [!NOTE]
> **Terminologi Penting — Texture vs Grain:**  
> Mulai Phase 6, label user-facing untuk grain diubah dari "Grain" menjadi **"Texture"**.  
> Texture secara internal memetakan ke: grain intensity, grain size, dust amount, softness, dan film texture character.  
> Perubahan ini tidak merusak arsitektur internal — hanya label UI dan data model gaya yang berubah.

```
Preset
├── Color Parameters
├── Texture (grain + dust + softness)
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

**[NEW — Phase 6+] Layer 4 — Style Layer**: Parameter Rana Styles (Tone, Color, Texture, Style Strength, Undertone X/Y) yang diterapkan di atas base preset. Ini adalah lapisan adjustable yang bisa dikustomisasi per user.

Arsitektur berlapis ini memisahkan logika dasar (Engine) dengan data (Preset Recipes & Assets) sehingga penambahan preset baru di kemudian hari tidak memerlukan refaktorisasi kode program.

### 3. Skema Preset (Preset Schema) — Version 2

Skema JSON preset yang telah diperbarui untuk mendukung Base Preset + Style Layer:

```json
{
  "id": "rana_warm",
  "name": "Rana Warm",
  "category": "Classic",
  "color": {
    "temperature": 0.24,
    "contrast": 0.0,
    "saturation": 0.08
  },
  "grain": {
    "intensity": 0.1
  },
  "vignette": {
    "intensity": 0.05
  },
  "lut": "assets/luts/rana_warm_v1.png",
  "overlay": null,
  "behavior": null,
  "effects": {
    "lightLeak": { "intensity": 0.12, "variant": -1 },
    "dust": { "intensity": 0.04 },
    "bloom": { "threshold": 0.78, "intensity": 0.05 },
    "halation": { "intensity": 0.03 },
    "lensDistortion": { "strength": 0.06 }
  }
}
```

Untuk menyimpan RanaStyle (custom style oleh user):

```json
{
  "version": 2,
  "basePresetId": "rana_warm",
  "style": {
    "id": "my_warm_rose",
    "name": "My Warm Rose",
    "tone": 72,
    "color": 83,
    "texture": 38,
    "styleStrength": 80,
    "undertoneX": 0.35,
    "undertoneY": 0.18
  }
}
```

Internal mapping dari Texture value ke analog parameters:

```json
{
  "texture": {
    "grainIntensity": 0.38,
    "grainSize": 0.8,
    "dustIntensity": 0.08,
    "softness": 0.12
  }
}
```

Schema requirements:
- Harus memiliki versi (versioned).
- Harus bisa dikembangkan (extensible).
- Harus backward-compatible dengan preset JSON lama.
- Harus mendukung custom user-created styles.
- Harus mendukung komposisi basePreset + style layer.
- Harus mendukung import/export/share style di masa depan.

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

## 3.6. Research Basis — Photographic Styles Inspiration

> [!IMPORTANT]
> Rana **bukan** mencoba mengkloning UI Apple atau mengklaim feature parity dengan iPhone.  
> Riset Apple Photographic Styles digunakan hanya sebagai **inspirasi produk dan arsitektur**.  
> Implementasi Rana adalah **Android shader-based approximation**, bukan Apple ISP parity.

### Apa itu Apple Photographic Styles?
Apple Photographic Styles (diperkenalkan di iPhone 13, diperluas di iPhone 16 / iOS 18) adalah sistem pipeline-based yang menerapkan "style" kustom ke foto **mid-pipeline** oleh ISP kamera. Ini berbeda dari filter biasa karena:

- Diterapkan pada data sensor sebelum final rendering, bukan post-hoc di atas JPEG.
- Non-destructive: parameter tersimpan dan bisa diubah ulang tanpa kehilangan kualitas.
- Menggunakan tone curve dan color matrix adaptif, bukan LUT statis.
- Dapat mempertahankan detail highlight/shadow dan melindungi skin tone.

Controls user-facing yang disediakan Apple:
- **Tone** — mengontrol mood tonal (contrast, brightness, shadow lift)
- **Color** — mengontrol intensitas warna (saturation/vibrance)
- **Intensity** — seberapa kuat style diterapkan (0–100%)
- **Undertone Grid** (iOS 18) — 2D pad untuk Warm↔Cool vs Green↔Magenta

### Perbedaan dengan LUT dan Filter Biasa
| Pendekatan | Cara Kerja | Reversible | Adaptif |
|---|---|---|---|
| Filter biasa / Dazz Cam | Static overlay di atas JPEG | ❌ | ❌ |
| LUT-based preset | Remaps setiap RGB pixel secara statis | ❌ | ❌ |
| Apple Photographic Styles | Parameterized ISP transform, mid-pipeline | ✅ | ✅ |
| **Rana Styles (Phase 6)** | Shader uniforms di GPU pipeline, post-capture | ✅ | Partial |

### Mengapa Rana Tidak Bisa Replikasi Penuh?
Apple menggunakan:
1. ISP (Image Signal Processor) proprietary yang tidak bisa diakses Android pihak ketiga.
2. Machine learning untuk segmentasi skin tone, sky, dll.
3. RAW sensor data sebagai input untuk style adjustments.

Rana menggunakan:
- CameraX (YUV → JPEG, tidak ada akses RAW yang konsisten antar device).
- OpenGL ES custom fragment shader (GPU compute, bukan ISP).
- Preset Engine + LUT support yang sudah ada.

### Tujuan Desain Rana Styles
Membawa **kesederhanaan UX Photographic Styles** ke dalam identitas produk kamera film Rana, dengan cara:
- Menyembunyikan parameter teknis dari user.
- Menggunakan bahasa yang intuitif: Tone, Color, Texture.
- Memberikan 2D Undertone pad untuk color balance visual.
- Mempertahankan konsistensi preview vs export.

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
- Grain (animated, non-static).
- Light leak (screen blend, animated random UV offset).
- Dust and scratches (multiply blend, animated UV offset, 1s interval).
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

## Rendering Order (Final — Wajib Diikuti)
```
1. Lens Distortion (UV warp — dilakukan PERTAMA)
2. Color Grading / LUT (Phase 4)
3. Temperature / Saturation / Contrast (Phase 3)
4. Bloom / Halation (multi-pass FBO)
5. Light Leak (screen blend)
6. Dust & Scratches (multiply blend)
7. Film Grain (animated noise)
8. Vignette
9. Clamp(0.0, 1.0)
```

## Acceptance Criteria
- Efek terasa analog, bukan sekadar filter biasa.
- Efek tidak terlalu berat.
- Preview tetap lancar.

## Difficulty
**Hard**

## Frontier Model Priority
**High**

## Status
✅ **Completed**

---

# Phase 6 — Rana Styles Engine

## Objective
Membangun sistem style adjustment yang terinspirasi Apple Photographic Styles, diadaptasi untuk Rana.

Rana Styles memungkinkan pengguna menyesuaikan visual mood dari preset yang sudah ada tanpa perlu memahami kontrol kamera teknis. User tidak perlu tahu ISO, shutter speed, EV, curves, gamma, atau color matrix.

Sebaliknya, control user yang ditampilkan adalah:
- **Tone**
- **Color**
- **Texture**
- **Style Strength**
- **Undertone Grid**

## Concept

```1
Base Preset (e.g. Rana Warm)
+
Rana Style Parameters
  - Tone 72
  - Color 83
  - Texture 38
  - Style Strength 80
  - Undertone Warm/Rose
======================
My Rana Warm
(saved as custom style)
```

## Deliverables
- RanaStyle data model.
- JSON schema migration dari Preset-only ke Preset + Style Layer.
- Style state management di Flutter camera controller.
- Compact style parameter strip di main capture screen (TONE / COLOR / TEXTURE).
- Expanded Rana Styles panel.
- Tone slider.
- Color slider.
- Texture slider (menggantikan Grain sebagai label user-facing utama).
- Style Strength slider.
- Undertone 2D direction pad (Warm↔Cool vs Green↔Magenta).
- Save as Style.
- Apply Style.
- Reset Style.
- Preview/export consistency menggunakan parameter style yang sama.
- Native shader uniform mapping.

---

## User-Facing Controls

### 1. Tone

**Label:** `TONE`

**Purpose:** Mengontrol mood tonal.

**Internal mapping:**
- contrast
- gamma / tone curve
- shadow lift
- highlight rolloff

**User sees:** `TONE 72`

**Shader uniform:** `uTone`

**Implementation note:** Dapat diimplementasikan sebagai power function pada luminance channel:  
`L_out = pow(L_in, pow(2.0, toneValue / 100.0))`

---

### 2. Color

**Label:** `COLOR`

**Purpose:** Mengontrol intensitas warna.

**Internal mapping:**
- saturation
- vibrance-like adjustment
- chroma scaling

**User sees:** `COLOR 83`

**Shader uniform:** `uColor`

**Implementation note:** Dalam Lab space atau HSV:  
`C' = C * (1.0 + colorValue / 100.0)`

---

### 3. Texture

**Label:** `TEXTURE`

**Purpose:** Mengontrol karakter surface film analog.

**Internal mapping:**
- grain intensity
- grain size
- dust amount
- softness
- film texture character

**User sees:** `TEXTURE 38`

**Shader uniform:** `uTexture`

> [!IMPORTANT]
> Jangan expose raw grain controls sebagai UI utama di Phase 6.  
> Texture adalah label yang lebih premium, fleksibel, dan intuitif.

**Internal mapping contoh:** Nilai `TEXTURE 38` → `{ grainIntensity: 0.38, grainSize: 0.8, dustIntensity: 0.08, softness: 0.12 }`

---

### 4. Style Strength

**Label:** `STYLE STRENGTH`

**Purpose:** Mengontrol seberapa kuat style layer diterapkan.

**Internal mapping:**
- blend amount antara base preset dan styled output
- LUT/style blend strength
- effect intensity multiplier

**Range:** 0–100

**Shader uniform:** `uStyleStrength`

---

### 5. Undertone Grid

**Label:** `UNDERTONE`

**Purpose:** 2D control pad yang mengatur arah warna secara visual.

**Axes:**
- X-axis: `Warm ↔ Cool`
- Y-axis: `Green / Olive ↔ Magenta / Rose`

**Behavior:**
- Move right → cooler / more blue
- Move left → warmer / more amber
- Move up → more magenta / rose
- Move down → more green / olive

**Shader uniforms:** `uUndertoneX`, `uUndertoneY`

**Implementation note (dari apple_tonal.md):**  
Menggunakan color balance matrix:
```glsl
// Approx model in RGB space
float alpha = kTemp * uUndertoneX;   // warm-cool
float beta  = kTint * uUndertoneY;   // green-magenta

mat3 M = mat3(
  1.0 + alpha,  0.0,         0.0,
  0.0,          1.0 - beta,  0.0,
  0.0,          0.0,         1.0 - alpha
) + mat3(
  0.0,  0.0,   0.0,
  0.0,  beta,  0.0,
  0.0,  0.0,   beta
);

color = M * color;
```

Atau dalam Lab space:
```
a' = a + k_tint  * uUndertoneY   // magenta-green
b' = b + k_temp  * uUndertoneX   // amber-cool
```

---

## UI/UX Requirements

### Main Capture Screen

Main capture screen harus tetap:
- camera-first
- minimal
- tidak terlalu teknis
- premium
- analog-inspired

Tambahkan compact style parameter strip yang tampil **di dalam atau di atas Rana Action Plate**:

```
[ TONE 72 ]  [ COLOR 83 ]  [ TEXTURE 38 ]
```

Jangan tambahkan full editor complexity ke main camera screen.

### Expanded Rana Styles Panel

Ketika user tap tombol "Style", buka expanded panel yang berisi:
- preview image / live preview area
- nama preset aktif
- Tone slider
- Color slider
- Texture slider
- Style Strength slider
- Undertone 2D pad (labeled axes: Warm↔Cool, Green↔Magenta)
- Reset button
- Apply button
- Save as Style button

UI harus terasa lebih dekat ke **iPhone Photographic Styles** daripada Lightroom.

**Hindari menampilkan:**
- exposure
- gamma
- lift/gain
- HSL sliders
- RGB channels
- curve editor
- pro mode controls

### User Flow

```
User selects preset
↓
User taps Style button
↓
Expanded Rana Styles panel terbuka
↓
Adjusts Tone / Color / Texture
↓
Adjusts Undertone direction pad
↓
Applies style (Apply button)
↓
Optionally saves as custom style (Save as Style)
```

**Contoh:**
```
Rana Warm
↓ Style
Tone 68, Color 82, Texture 42, Undertone Rose/Warm
↓ Save as Style
"My Warm Rose"
```

---

## Engine Architecture

### Conceptual Rendering Order (Phase 6)

```
Base camera frame
↓
Base preset recipe (LUT + color params)
↓
Analog effects defaults (grain, light leak, dust)
↓
[NEW] Rana Style Layer
  ↓ Tone adjustment (uTone)
  ↓ Color adjustment (uColor)
  ↓ Texture adjustment (uTexture → grain + dust override)
  ↓ Undertone color matrix (uUndertoneX, uUndertoneY)
  ↓ Style Strength blend (uStyleStrength)
↓
Final preview / export
```

**Important:** Preview pipeline dan export pipeline harus menggunakan style parameters yang sama.

### Shader Uniforms (Phase 6)

```glsl
uniform float uTone;           // -100..100
uniform float uColor;          // -100..100
uniform float uTexture;        // 0..100
uniform float uStyleStrength;  // 0..100
uniform float uUndertoneX;     // -1.0..1.0 (warm-cool)
uniform float uUndertoneY;     // -1.0..1.0 (green-magenta)
```

### GLSL Implementation Sketch

```glsl
vec3 color = texture2D(sTexture, vTextureCoord).rgb;

// 1. Apply base preset LUT (if any)
color = sampleLUT(color, uLutTexture, uStyleStrength);

// 2. Tone adjustment (gamma / tone curve)
color = pow(color, vec3(pow(2.0, uTone / 100.0)));

// 3. Color / saturation
float avg = (color.r + color.g + color.b) / 3.0;
color = mix(vec3(avg), color, 1.0 + uColor / 100.0);

// 4. Undertone color balance matrix
float alpha = 0.15 * uUndertoneX;
float beta  = 0.12 * uUndertoneY;
color.r = color.r * (1.0 + alpha + beta);
color.g = color.g * (1.0 - beta);
color.b = color.b * (1.0 - alpha + beta);

color = clamp(color, 0.0, 1.0);
```

---

## Technical Requirements

### Preview Pipeline
- Style changes harus update preview secara realtime.
- Tone, Color, Texture, dan Undertone tidak boleh restart camera session.
- Gunakan shader uniforms, bukan rebuild shader setiap adjustment.
- Style changes harus smooth (tidak ada frame drop saat slider di-drag).

### Export Pipeline
- Foto yang di-export harus match preview semaksimal mungkin.
- Offline processor harus menerima RanaStyle parameters yang sama.
- Style parameters dimasukkan ke output metadata jika memungkinkan.

### Performance
- Realtime preview tetap stabil (target: 24–30 FPS).
- Hindari heavy multi-pass rendering untuk Phase 6 V1.
- Gunakan shader math sederhana untuk Tone/Color/Undertone.
- Texture reuse existing grain system dari Phase 5.
- Tidak ada ML/segmentation di Phase 6 V1.

---

## Tasks

1. Buat `RanaStyle` model (Dart).
2. Extend preset schema ke Preset + Style Layer (versioned JSON schema v2).
3. Tambahkan style state ke Flutter camera controller.
4. Tambahkan compact style parameter strip di main capture screen (TONE / COLOR / TEXTURE).
5. Buat expanded Rana Styles panel.
6. Implement Tone slider.
7. Implement Color slider.
8. Implement Texture slider (mapping ke grain/dust/softness engine).
9. Implement Style Strength slider.
10. Implement Undertone 2D pad.
11. Map Undertone X/Y ke shader color balance matrix.
12. Map Texture value ke existing grain/dust/softness engine dari Phase 5.
13. Pass style params dari Flutter ke native renderer via MethodChannel.
14. Tambahkan OpenGL shader uniforms (uTone, uColor, uTexture, uStyleStrength, uUndertoneX, uUndertoneY).
15. Apply style params di realtime preview (CameraGlRenderer).
16. Apply style params di offline export (OfflineGlProcessor).
17. Implement Reset Style.
18. Implement Apply Style.
19. Implement Save as Style.
20. Persist custom style JSON secara lokal.
21. Verifikasi preview/export consistency (tambahkan style params ke GL Shader Consistency debug screen).
22. Tambahkan debug panel/logging untuk style params.

---

## Acceptance Criteria

- Main capture screen menampilkan compact style parameters (TONE / COLOR / TEXTURE).
- User bisa membuka Rana Styles panel dari capture screen.
- User bisa adjust Tone dan melihat preview update realtime.
- User bisa adjust Color dan melihat preview update realtime.
- User bisa adjust Texture dan melihat grain/film texture update.
- User bisa adjust Undertone pad dan melihat warm/cool/green/magenta bias update.
- User bisa reset style.
- User bisa apply style.
- User bisa save custom style.
- Exported image secara visual match preview.
- Preset lama tetap berjalan (backward compatible).
- Old preset schema tetap didukung.
- Tidak ada camera restart saat mengubah style parameters.
- Tidak ada FPS regression signifikan.

---

## Phase 6 Non-Goals

**Jangan dimasukkan di Phase 6 V1:**
- Apple-level ISP integration
- RAW-based non-destructive editing
- ML skin segmentation
- Full Lightroom-style editor
- Curve editor
- HSL panel
- Manual camera mode
- Video styles
- Cloud sync
- Style marketplace

---

## Difficulty
**Very Hard**

## Frontier Model Priority
**Very High**

## Why
Phase ini memperkenalkan style layer system baru, realtime shader parameter control, UI complexity, preview/export consistency requirements, dan schema evolution. Keputusan arsitektur di phase ini mempengaruhi semua preset customization, custom styles, dan long-term product differentiation.

---

# Phase 7 — Gallery, History, and Sharing

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

# Phase 8 — Advanced Effects

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

# Phase 9 — Performance, Compatibility, and Device Tuning

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

# Phase 10 — Monetization / Premium Structure (Optional)

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

# Phase 11 — Video Recording (Belakangan)

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

### Frontier model should handle:
1. **Phase 6 — Rana Styles Engine** ← Highest priority for current phase
2. **Phase 4 — High-Resolution Export & LUT Support**
3. **Phase 8 — Advanced Effects**
4. **Phase 9 — Performance, Compatibility, and Device Tuning**
5. **Phase 11 — Video Recording**

### Medium model or general agent can handle:
1. Phase 0 — Foundation
2. Phase 1 — Basic Camera Capture
3. Phase 2 — Live Preview Effect Pipeline (initial scaffolding)
4. Phase 7 — Gallery & Sharing
5. Phase 10 — Monetization structure
6. UI polish, documentation, non-critical CRUD

---

## 6. Suggested MVP Definition

### MVP v1 for Rana (Phases 0–5 Complete)
- Flutter shell.
- Native camera preview.
- 5 film presets (Rana Warm, Rana Cool, Rana Mono + 2 more).
- Realtime filter preview.
- Capture photo.
- High-res save.
- Grain (animated).
- Light leak.
- Dust & scratches overlay.
- Date stamp.
- Gallery preview.

### Beta Target (Phase 6 Complete)
- Everything in MVP v1.
- Compact style strip on main screen (TONE / COLOR / TEXTURE).
- Expanded Rana Styles panel.
- Undertone grid.
- Save as Style feature.
- Preview/export style consistency.

### Not in MVP v1 or Beta
- Video.
- Double exposure.
- Cloud sync.
- Login.
- Style marketplace.

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
- MediaCodec (Phase 11)
- Kotlin for bridge/plugin code

### Data & Assets
- LUT textures (2D/3D PNG)
- Overlay PNG assets (light leak, dust, frames)
- JSON preset metadata (v1 schema: base preset)
- JSON style metadata (v2 schema: RanaStyle)

### Architecture Style
- Feature-first modular structure
- Flutter UI as shell
- Native rendering/camera engine under it
- Shader uniforms as the parameter transport mechanism (no camera restart on style change)

---

## 8. Final Product Direction

Rana should not compete only by having many presets.

Rana should compete by combining:

```
Film Presets
+
Analog Effects (Phase 5)
+
Rana Styles (Phase 6)
```

This allows users to create their own personal visual look without using a professional editor.

**Positioning:**
> Dazz Cam gives many looks.  
> Rana gives cinematic film looks that users can subtly shape into their own.

Rana should feel like:
- fast to open,
- simple to use,
- visually distinctive,
- film-inspired,
- and stable on real Android devices.

The highest-risk technical areas are the ones that need frontier-level assistance:
- **Phase 6 — Rana Styles Engine** (realtime shader style pipeline, undertone math, style-export consistency)
- realtime shader pipeline (Phase 2–5),
- high-res export consistency (Phase 4),
- advanced analog effects (Phase 8),
- and video later (Phase 11).
