// Shared studio color picker (Shared::StudioColorPickerComponent): preset
// swatches, the colors last picked in this browser and a custom color field,
// in an <inline-popup>.
//
// Picking a swatch, dragging in the native color field or typing a hex value
// only selects a color: the picker fires "studio-color-picker:change"
// (detail.color) so the owner can preview it. "Übernehmen" fires
// "studio-color-picker:apply" and remembers the color in localStorage, where
// every picker offers it first. Closing any other way ("Abbrechen", Escape,
// a click outside) after a preview fires "studio-color-picker:cancel", and
// the owner restores what it had before the first change. The owner sets the
// current color with setValue(); all events bubble from the picker.
App.Studio.StudioColorPicker = {
  storageKey: "studio-color-picker-recent-colors",
  hexPattern: /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i,
  storedHexPattern: /^#[0-9a-f]{6}$/i,
  sessions: new WeakMap(),

  initialize() {
    const $document = $(document);

    $document.on("inline-popup:open", ".js-studio-color-picker-popup", this.handleOpen.bind(this));
    $document.on("inline-popup:close", ".js-studio-color-picker-popup", this.handleClose.bind(this));
    $document.on("click", ".js-studio-color-picker-swatch", this.handleSwatchClick.bind(this));
    $document.on("input", ".js-studio-color-picker-native", this.handleNativeInput.bind(this));
    $document.on("input", ".js-studio-color-picker-hex", this.handleHexInput.bind(this));
    $document.on("keydown", ".js-studio-color-picker-hex", this.handleHexKeydown.bind(this));
    $document.on("click", ".js-studio-color-picker-apply", this.handleApplyClick.bind(this));
  },

  setValue(picker, color) {
    if (picker.dataset.value !== color) {
      picker.dataset.value = color;
    }
  },

  pickerFor(element) {
    return element.closest(".js-studio-color-picker")
  },

  getPopup(picker) {
    return picker.querySelector(".js-studio-color-picker-popup");
  },

  getNativeInput(picker) {
    return picker.querySelector(".js-studio-color-picker-native");
  },

  getHexInput(picker) {
    return picker.querySelector(".js-studio-color-picker-hex");
  },

  getError(picker) {
    return picker.querySelector(".js-studio-color-picker-error");
  },

  handleOpen(e) {
    const picker = this.pickerFor(e.currentTarget);

    this.sessions.set(picker, { originalColor: picker.dataset.value, changed: false, applied: false });
    this.renderRecentColors(picker);
    this.markCurrentColor(picker);
    this.fillCustomFields(picker, picker.dataset.value);
    this.hideError(picker);
  },

  handleClose(e) {
    const picker = this.pickerFor(e.currentTarget);
    const session = this.sessions.get(picker);

    this.sessions.delete(picker);

    if (!session || !session.changed || session.applied) return

    this.setValue(picker, session.originalColor);
    this.dispatch(picker, "studio-color-picker:cancel", session.originalColor);
  },

  handleSwatchClick(e) {
    e.preventDefault();

    const swatch = e.currentTarget;
    const picker = this.pickerFor(swatch);

    this.hideError(picker);
    this.fillCustomFields(picker, swatch.dataset.color);
    this.selectColor(picker, swatch.dataset.color);
  },

  handleNativeInput(e) {
    const input = e.currentTarget;
    const picker = this.pickerFor(input);

    this.getHexInput(picker).value = input.value;
    this.hideError(picker);
    this.selectColor(picker, input.value);
  },

  // A complete hex value previews as it is typed; a partial one waits.
  handleHexInput(e) {
    const input = e.currentTarget;
    const picker = this.pickerFor(input);
    const color = this.normalizeHex(input.value.trim());

    if (!color) return

    this.hideError(picker);
    this.getNativeInput(picker).value = color;
    this.selectColor(picker, color);
  },

  handleHexKeydown(e) {
    if (e.key !== "Enter") return

    e.preventDefault();
    this.applySelection(this.pickerFor(e.currentTarget));
  },

  handleApplyClick(e) {
    e.preventDefault();

    this.applySelection(this.pickerFor(e.currentTarget));
  },

  selectColor(picker, color) {
    if (picker.dataset.value === color) return

    const session = this.sessions.get(picker);

    if (session) {
      session.changed = true;
    }

    this.setValue(picker, color);
    this.markCurrentColor(picker);
    this.dispatch(picker, "studio-color-picker:change", color);
  },

  // The hex field wins when it holds text, so a value typed but not yet
  // valid is reported instead of applying an older selection.
  applySelection(picker) {
    const hexText = this.getHexInput(picker).value.trim();
    const color = hexText ? this.normalizeHex(hexText) : picker.dataset.value;
    const session = this.sessions.get(picker);

    if (hexText && !color) {
      this.showError(picker);

      return
    }

    if (color) {
      this.selectColor(picker, color);
      this.rememberColor(picker, color);
      this.dispatch(picker, "studio-color-picker:apply", color);
    }

    if (session) {
      session.applied = true;
    }

    this.getPopup(picker).close();
  },

  dispatch(picker, eventName, color) {
    picker.dispatchEvent(new CustomEvent(eventName, { bubbles: true, detail: { color: color } }));
  },

  markCurrentColor(picker) {
    const color = picker.dataset.value;

    picker.querySelectorAll(".js-studio-color-picker-swatch").forEach((swatch) => {
      swatch.setAttribute("aria-pressed", String(swatch.dataset.color === color));
    });
  },

  // Only hex colors fit the custom fields; for anything else (the brand
  // color variable, a gradient) the hex field is emptied.
  fillCustomFields(picker, color) {
    const hexColor = this.normalizeHex(color || "");

    this.getHexInput(picker).value = hexColor || "";

    if (hexColor) {
      this.getNativeInput(picker).value = hexColor;
    }
  },

  renderRecentColors(picker) {
    const template = picker.querySelector(".js-studio-color-picker-recent-swatch-template");
    const colors = this.recentColors(picker);
    const swatches = colors.map((color) => this.buildRecentSwatch(picker, template, color));

    picker.querySelector(".js-studio-color-picker-recent-swatches").replaceChildren(...swatches);
    picker.querySelector(".js-studio-color-picker-recent-section").hidden = colors.length === 0;
  },

  buildRecentSwatch(picker, template, color) {
    const swatch = template.content.firstElementChild.cloneNode(true);

    swatch.dataset.color = color;
    swatch.style.setProperty("--studio-color-picker-swatch-color", color);
    swatch.setAttribute("aria-label", this.colorName(picker, color));

    return swatch
  },

  // A remembered preset keeps its name, a custom color is named by its value.
  colorName(picker, color) {
    const preset = this.presetSwatch(picker, color);

    return preset ? preset.getAttribute("aria-label") : color
  },

  presetSwatch(picker, color) {
    return Array
      .from(picker.querySelectorAll(".js-studio-color-picker-presets .js-studio-color-picker-swatch"))
      .find((swatch) => swatch.dataset.color === color)
  },

  rememberColor(picker, color) {
    if (!this.isTrustedColor(picker, color)) return

    const otherColors = this.recentColors(picker).filter((recentColor) => recentColor !== color);
    const colors = [color].concat(otherColors).slice(0, this.recentLimit(picker));

    try {
      localStorage.setItem(this.storageKey, JSON.stringify(colors));
    } catch (error) {
      // Storage disabled or full: the picker keeps working without recents.
    }
  },

  recentColors(picker) {
    return this
      .storedColors()
      .filter((color) => this.isTrustedColor(picker, color))
      .slice(0, this.recentLimit(picker));
  },

  // Stored values end up in inline styles of saved content, so only hex
  // colors and this picker's presets are trusted (never a gradient or a
  // value with a stray semicolon).
  isTrustedColor(picker, color) {
    return this.storedHexPattern.test(color) || Boolean(this.presetSwatch(picker, color))
  },

  storedColors() {
    try {
      const colors = JSON.parse(localStorage.getItem(this.storageKey) || "[]");

      return Array.isArray(colors) ? colors.filter((color) => typeof color === "string") : []
    } catch (error) {
      return []
    }
  },

  recentLimit(picker) {
    return parseInt(picker.dataset.recentLimit, 10)
  },

  normalizeHex(value) {
    const match = value.match(this.hexPattern);

    if (!match) return null

    const digits = match[1].length === 3 ? match[1].replace(/./g, "$&$&") : match[1];

    return `#${digits.toLowerCase()}`
  },

  showError(picker) {
    const hexInput = this.getHexInput(picker);

    this.getError(picker).hidden = false;
    hexInput.setAttribute("aria-invalid", "true");
    hexInput.focus();
  },

  hideError(picker) {
    this.getError(picker).hidden = true;
    this.getHexInput(picker).removeAttribute("aria-invalid");
  }
};
