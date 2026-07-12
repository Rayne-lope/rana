document.addEventListener('DOMContentLoaded', () => {
  // Select control inputs
  const presetIdInput = document.getElementById('preset-id');
  const presetNameInput = document.getElementById('preset-name');
  const presetCategoryInput = document.getElementById('preset-category');

  // Select all range sliders
  const sliders = {
    temperature: document.getElementById('param-temperature'),
    contrast: document.getElementById('param-contrast'),
    saturation: document.getElementById('param-saturation'),
    grain: document.getElementById('param-grain'),
    vignette: document.getElementById('param-vignette'),
    lightLeak: document.getElementById('param-lightLeak'),
    lightLeakVariant: document.getElementById('param-lightLeakVariant'),
    dust: document.getElementById('param-dust'),
    bloom: document.getElementById('param-bloom'),
    bloomThreshold: document.getElementById('param-bloomThreshold'),
    halation: document.getElementById('param-halation'),
    lensDistortion: document.getElementById('param-lensDistortion'),
    styleTone: document.getElementById('param-styleTone'),
    styleColor: document.getElementById('param-styleColor'),
    styleStrength: document.getElementById('param-styleStrength'),
    undertoneX: document.getElementById('param-undertoneX'),
    undertoneY: document.getElementById('param-undertoneY')
  };

  // Select buttons & output
  const jsonOutput = document.getElementById('json-output');
  const btnCopy = document.getElementById('btn-copy');
  const btnDownload = document.getElementById('btn-download');

  // Preview elements
  const images = [
    document.getElementById('prev-img-1'),
    document.getElementById('prev-img-2'),
    document.getElementById('prev-img-3'),
    document.getElementById('prev-img-4'),
    document.getElementById('prev-img-5')
  ];

  // Auto fallback for extensions (.jpg -> .jpeg -> .png)
  images.forEach((img, index) => {
    if (!img) return;
    const sampleNum = index + 1;

    function tryNextExtension() {
      const currentSrc = img.getAttribute('src') || '';
      if (currentSrc.endsWith('.jpg')) {
        img.setAttribute('src', `images/sample${sampleNum}.jpeg`);
      } else if (currentSrc.endsWith('.jpeg')) {
        img.setAttribute('src', `images/sample${sampleNum}.png`);
      } else {
        img.classList.remove('loaded');
      }
    }

    img.addEventListener('error', tryNextExtension);
    
    img.addEventListener('load', () => {
      if (img.naturalWidth > 0) {
        img.classList.add('loaded');
      }
    });

    // Initial check in case it's already loaded or failed
    if (img.complete) {
      if (img.naturalWidth > 0) {
        img.classList.add('loaded');
      } else {
        tryNextExtension();
      }
    }
  });

  const vignettes = [
    document.getElementById('vignette-1'),
    document.getElementById('vignette-2'),
    document.getElementById('vignette-3'),
    document.getElementById('vignette-4'),
    document.getElementById('vignette-5')
  ];

  const lightleaks = [
    document.getElementById('lightleak-1'),
    document.getElementById('lightleak-2'),
    document.getElementById('lightleak-3'),
    document.getElementById('lightleak-4'),
    document.getElementById('lightleak-5')
  ];

  // Helper to get color gradients for light leak variants
  function getLightLeakGradient(variant, intensity) {
    if (intensity <= 0 || variant < 0) return 'none';
    const alpha = intensity * 0.75;
    switch (parseInt(variant)) {
      case 0: // Orange sweep
        return `linear-gradient(135deg, rgba(243, 156, 18, ${alpha}) 0%, rgba(231, 76, 60, ${alpha}) 50%, transparent 100%)`;
      case 1: // Red sweep
        return `linear-gradient(90deg, rgba(217, 30, 24, ${alpha}) 0%, transparent 80%)`;
      case 2: // Purple-blue sweep
        return `linear-gradient(45deg, rgba(142, 68, 173, ${alpha}) 0%, rgba(41, 128, 185, ${alpha}) 100%)`;
      case 3: // Yellow-green glow
        return `linear-gradient(210deg, rgba(241, 196, 15, ${alpha}) 0%, rgba(39, 174, 96, ${alpha}) 80%)`;
      case 4: // Cyan/orange radial flare
        return `radial-gradient(circle at top right, rgba(52, 152, 219, ${alpha * 1.2}) 0%, rgba(230, 126, 34, ${alpha * 0.8}) 50%, transparent 100%)`;
      default:
        return 'none';
    }
  }

  // Update readouts, generate JSON and update CSS filters on preview images
  function updateConsole() {
    const data = {
      id: presetIdInput.value.trim() || 'custom_preset',
      name: presetNameInput.value.trim() || 'Custom Preset',
      category: presetCategoryInput.value,
      color: {
        temperature: parseFloat(sliders.temperature.value),
        contrast: parseFloat(sliders.contrast.value),
        saturation: parseFloat(sliders.saturation.value)
      },
      grain: {
        intensity: parseFloat(sliders.grain.value)
      },
      vignette: {
        intensity: parseFloat(sliders.vignette.value)
      },
      lut: null,
      overlay: null,
      behavior: null,
      effects: {
        lightLeak: {
          intensity: parseFloat(sliders.lightLeak.value),
          variant: parseInt(sliders.lightLeakVariant.value)
        },
        dust: {
          intensity: parseFloat(sliders.dust.value)
        },
        bloom: {
          threshold: parseFloat(sliders.bloomThreshold.value),
          intensity: parseFloat(sliders.bloom.value)
        },
        halation: {
          intensity: parseFloat(sliders.halation.value)
        },
        lensDistortion: {
          strength: parseFloat(sliders.lensDistortion.value)
        }
      },
      style: {
        tone: parseFloat(sliders.styleTone.value),
        color: parseFloat(sliders.styleColor.value),
        styleStrength: parseFloat(sliders.styleStrength.value),
        undertoneX: parseFloat(sliders.undertoneX.value),
        undertoneY: parseFloat(sliders.undertoneY.value)
      }
    };

    // Update readout values text
    for (const key in sliders) {
      const readout = document.getElementById(`readout-${key}`);
      if (readout) {
        if (key === 'lightLeakVariant' || key === 'styleTone' || key === 'styleColor' || key === 'styleStrength') {
          readout.textContent = sliders[key].value;
        } else {
          // Format with 2 decimals
          readout.textContent = parseFloat(sliders[key].value).toFixed(2);
        }
      }
    }

    // Format output as formatted JSON
    jsonOutput.textContent = JSON.stringify(data, null, 2);

    // Apply Live Preview filter effects to images
    const temp = parseFloat(sliders.temperature.value);
    const sat = parseFloat(sliders.saturation.value);
    const con = parseFloat(sliders.contrast.value);
    const bloom = parseFloat(sliders.bloom.value);

    // Build custom CSS filter string
    let filterString = `saturate(${Math.max(0, 1 + sat)}) contrast(${Math.max(0, 1 + con * 0.5)})`;
    if (temp > 0) {
      filterString += ` sepia(${temp * 35}%)`;
    } else if (temp < 0) {
      // Rotate hue cool-wards and restore slight blue saturation
      filterString += ` hue-rotate(${temp * 18}deg) saturate(${1 - temp * 0.15})`;
    }
    if (bloom > 0) {
      filterString += ` brightness(${1 + bloom * 0.05})`;
    }

    images.forEach(img => {
      if (img) img.style.filter = filterString;
    });

    // Update Vignette Overlays
    const vig = parseFloat(sliders.vignette.value);
    vignettes.forEach(vigDiv => {
      if (vigDiv) {
        vigDiv.style.background = `radial-gradient(circle, transparent ${Math.max(10, 100 - vig * 75)}%, rgba(0,0,0,${vig * 0.95}) 100%)`;
      }
    });

    // Update Light Leak Overlays
    const leakIntensity = parseFloat(sliders.lightLeak.value);
    const leakVariant = parseInt(sliders.lightLeakVariant.value);
    const leakGrad = getLightLeakGradient(leakVariant, leakIntensity);
    lightleaks.forEach(leakDiv => {
      if (leakDiv) {
        leakDiv.style.background = leakGrad;
      }
    });
  }

  // Attach input event listeners to all sliders
  Object.values(sliders).forEach(slider => {
    slider.addEventListener('input', updateConsole);
  });

  // Metadata listeners
  presetIdInput.addEventListener('input', updateConsole);
  presetNameInput.addEventListener('input', updateConsole);
  presetCategoryInput.addEventListener('change', updateConsole);

  // Copy JSON action
  btnCopy.addEventListener('click', () => {
    const text = jsonOutput.textContent;
    navigator.clipboard.writeText(text).then(() => {
      const originalText = btnCopy.textContent;
      btnCopy.textContent = 'Copied!';
      btnCopy.classList.add('active');
      setTimeout(() => {
        btnCopy.textContent = originalText;
        btnCopy.classList.remove('active');
      }, 1500);
    });
  });

  // Download json file action
  btnDownload.addEventListener('click', () => {
    const filename = `${presetIdInput.value.trim() || 'custom_preset'}.json`;
    const jsonStr = jsonOutput.textContent;
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  });

  // Run initialization
  updateConsole();
});
