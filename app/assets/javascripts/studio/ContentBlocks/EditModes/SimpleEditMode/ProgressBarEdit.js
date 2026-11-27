// Progress bar editing for simple edit mode.
//
// A bar is recognised by its shape, so blocks saved before this editor
// existed and AI-built ones get controls too: an empty fill with an inline
// "width: N%" and "height: 100%" inside a track with an inline
// "overflow: hidden". Its "NN %" text is the first percentage found in the
// nearest container that holds no other bar.
//
// While simple edit mode is on, every bar gets a slider laid over its track
// and a StudioColorPicker below its left end, on the block's ControlLayer. The
// slider rewrites the fill width and the "NN %" text together; typing a new
// percentage into the text moves the bar.
App.Studio.ContentBlocks.SimpleEditMode.ProgressBarEdit = {
  percentagePattern: /^(\d{1,3}(?:[.,]\d+)?)\s*%$/,
  fillWidthPattern: /^(\d{1,3}(?:\.\d+)?)%$/,
  labelNumberPattern: /\d{1,3}(?:[.,]\d+)?(?=\s*%)/,
  backgroundProperties: ["background", "background-color", "background-image"],
  blockStates: new Map(),
  barByControl: new WeakMap(),

  initialize() {
    const $document = $(document);

    $document.on("input", ".js-progress-bar-slider", this.handleSliderInput.bind(this));
    $document.on("studio-color-picker:change", ".js-progress-bar-color-picker", this.handleColorChange.bind(this));
    $document.on("studio-color-picker:apply", ".js-progress-bar-color-picker", this.handleColorApply.bind(this));
    $document.on("studio-color-picker:cancel", ".js-progress-bar-color-picker", this.handleColorCancel.bind(this));
  },

  getControlTemplate() {
    return document.querySelector(".js-progress-bar-control-template");
  },

  toggleProgressBarControls(contentBlock, enabled) {
    if (enabled) {
      this.enableControls(contentBlock);
    } else {
      this.disableControls(contentBlock);
    }
  },

  enableControls(contentBlock) {
    if (this.blockStates.has(contentBlock)) return

    const layer = App.Studio.ContentBlocks.SimpleEditMode.ControlLayer.attach(contentBlock, {
      className: "studio-progress-bar-controls",
      mutationOptions: {
        childList: true,
        subtree: true,
        characterData: true,
        attributes: true,
        attributeFilter: ["style"]
      },
      onSync: () => this.syncControls(contentBlock),
      onDisconnect: () => this.disableControls(contentBlock)
    });

    this.blockStates.set(contentBlock, { layer: layer, bars: new Map() });
    this.syncControls(contentBlock);
  },

  disableControls(contentBlock) {
    const state = this.blockStates.get(contentBlock);

    if (!state) return

    App.Studio.ContentBlocks.SimpleEditMode.ControlLayer.detach(state.layer);
    this.blockStates.delete(contentBlock);
  },

  syncControls(contentBlock) {
    const state = this.blockStates.get(contentBlock);
    const fills = this.progressBarFillsIn(contentBlock);
    const tracks = fills.map((fill) => fill.parentElement);

    this.removeStaleBars(state, fills);

    const bars = fills.map((fill) => this.barFor(state, fill));

    bars.forEach((bar) => this.syncBar(bar, this.labelFor(contentBlock, bar.track, tracks)));

    // Every rect is read before any control is moved, so a sync costs one
    // layout instead of one per bar.
    const layerRect = state.layer.element.getBoundingClientRect();
    const placements = bars.map((bar) => ({ bar: bar, rect: bar.track.getBoundingClientRect() }));

    placements.forEach((placement) => this.placeControl(placement, layerRect));
  },

  removeStaleBars(state, fills) {
    state.bars.forEach((bar, fill) => {
      if (fills.includes(fill)) return

      bar.control.remove();
      App.Studio.ContentBlocks.SimpleEditMode.ControlLayer.unobserveResize(state.layer, bar.track);
      state.bars.delete(fill);
    });
  },

  barFor(state, fill) {
    const existingBar = state.bars.get(fill);

    if (existingBar) {
      this.followTrack(state, existingBar);

      return existingBar
    }

    const control = this.buildControl(state.layer.element);
    const bar = {
      fill: fill,
      track: fill.parentElement,
      control: control,
      slider: control.querySelector(".js-progress-bar-slider"),
      colorPicker: control.querySelector(".js-progress-bar-color-picker"),
      label: null,
      labelValue: null,
      colorSnapshot: null
    };

    this.barByControl.set(bar.control, bar);
    state.bars.set(fill, bar);
    App.Studio.ContentBlocks.SimpleEditMode.ControlLayer.observeResize(state.layer, bar.track);

    return bar
  },

  // Editing can move a fill into another track element.
  followTrack(state, bar) {
    const track = bar.fill.parentElement;

    if (track === bar.track) return

    App.Studio.ContentBlocks.SimpleEditMode.ControlLayer.unobserveResize(state.layer, bar.track);
    App.Studio.ContentBlocks.SimpleEditMode.ControlLayer.observeResize(state.layer, track);
    bar.track = track;
  },

  buildControl(layerElement) {
    const control = this.getControlTemplate().content.firstElementChild.cloneNode(true);

    layerElement.appendChild(control);

    return control
  },

  // A label new to the bar is only remembered, so entering simple edit mode
  // never rewrites a bar; a label whose number changed since moves the bar.
  syncBar(bar, label) {
    const value = this.labelValue(label);

    if (label !== bar.label) {
      bar.label = label;
      bar.labelValue = value;
    } else if (value !== null && value !== bar.labelValue) {
      bar.labelValue = value;
      this.applyWidth(bar, value);
    }

    this.updateSlider(bar, this.fillWidth(bar.fill));
    App.Studio.StudioColorPicker.setValue(bar.colorPicker, this.fillBackground(bar) || "");
  },

  placeControl(placement, layerRect) {
    const { bar, rect } = placement;
    const controlStyle = bar.control.style;

    controlStyle.display = rect.width > 0 ? "" : "none";
    controlStyle.left = `${rect.left - layerRect.left}px`;
    controlStyle.top = `${rect.top - layerRect.top}px`;
    controlStyle.width = `${rect.width}px`;
    controlStyle.height = `${rect.height}px`;
  },

  progressBarFillsIn(contentBlock) {
    return Array
      .from(contentBlock.querySelectorAll("div, span"))
      .filter((element) => this.isProgressBarFill(element, contentBlock));
  },

  isProgressBarFill(element, contentBlock) {
    const track = element.parentElement;

    if (element.children.length > 0 || element.textContent.trim() !== "") return false
    if (track === contentBlock) return false
    if (App.Studio.utils.inlineDeclaration(track, "overflow") !== "hidden") return false
    if (App.Studio.utils.inlineDeclaration(element, "height") !== "100%") return false

    return this.fillWidth(element) !== null
  },

  fillWidth(fill) {
    const match = (App.Studio.utils.inlineDeclaration(fill, "width") || "").match(this.fillWidthPattern);

    if (!match) return null

    const width = parseFloat(match[1]);

    return width <= 100 ? width : null
  },

  // Climbs from the track while the container holds no other bar, so a row's
  // label is never paired with the next row's bar.
  labelFor(contentBlock, track, tracks) {
    let container = track.parentElement;

    while (contentBlock.contains(container) && this.holdsOnlyTrack(container, track, tracks)) {
      const label = this.percentageLabelIn(container);

      if (label) return label

      container = container.parentElement;
    }

    return null
  },

  holdsOnlyTrack(container, track, tracks) {
    return tracks.every((otherTrack) => otherTrack === track || !container.contains(otherTrack))
  },

  percentageLabelIn(container) {
    return Array
      .from(container.querySelectorAll("*"))
      .find((element) => element.children.length === 0 && this.labelValue(element) !== null) || null
  },

  labelValue(label) {
    if (!label) return null

    const match = label.textContent.trim().match(this.percentagePattern);

    return match ? parseFloat(match[1].replace(",", ".")) : null
  },

  handleSliderInput(e) {
    const slider = e.currentTarget;
    const bar = this.barByControl.get(slider.closest(".js-progress-bar-control"));
    const value = parseInt(slider.value, 10);

    this.applyWidth(bar, value);
    this.writeLabelValue(bar, value);
  },

  applyWidth(bar, value) {
    const width = Math.min(Math.max(value, 0), 100);

    App.Studio.utils.setInlineDeclaration(bar.fill, "width", `${width}%`);
    this.updateSlider(bar, width);
  },

  // Only the number is replaced, so the label keeps its own separator
  // ("78 %", "78%").
  writeLabelValue(bar, value) {
    if (!bar.label) return

    const text = bar.label.textContent;
    const updatedText = text.replace(this.labelNumberPattern, String(value));

    if (updatedText !== text) {
      bar.label.textContent = updatedText;
    }

    bar.labelValue = value;
  },

  updateSlider(bar, width) {
    const value = String(Math.round(width));

    if (bar.slider.value !== value) {
      bar.slider.value = value;
    }
  },

  barForColorPicker(picker) {
    return this.barByControl.get(picker.closest(".js-progress-bar-control"))
  },

  // The first preview of a picker session saves the bar's styles as they
  // were, so a cancel restores them exactly, gradient fallbacks included.
  handleColorChange(e) {
    const bar = this.barForColorPicker(e.currentTarget);

    if (!bar.colorSnapshot) {
      bar.colorSnapshot = {
        fillStyle: bar.fill.getAttribute("style"),
        label: bar.label,
        labelStyle: bar.label && bar.label.getAttribute("style")
      };
    }

    this.applyColor(bar, e.originalEvent.detail.color);
  },

  handleColorApply(e) {
    this.barForColorPicker(e.currentTarget).colorSnapshot = null;
  },

  handleColorCancel(e) {
    const bar = this.barForColorPicker(e.currentTarget);
    const snapshot = bar.colorSnapshot;

    if (!snapshot) return

    this.restoreStyle(bar.fill, snapshot.fillStyle);

    if (snapshot.label) {
      this.restoreStyle(snapshot.label, snapshot.labelStyle);
    }

    bar.colorSnapshot = null;
  },

  restoreStyle(element, style) {
    if (style === null) {
      element.removeAttribute("style");
    } else {
      element.setAttribute("style", style);
    }
  },

  // A label filled in the bar's own color (the pill in the KPI template) is
  // recolored with it, its text switching to white or dark for contrast; any
  // other label keeps its look.
  applyColor(bar, color) {
    const declaration = `background: ${color}`;
    const labelMatchesFill = bar.label &&
      App.Studio.utils.inlineDeclaration(bar.label, "background") === this.fillBackground(bar);

    App.Studio.utils.replaceInlineDeclarations(bar.fill, this.backgroundProperties, declaration);

    if (labelMatchesFill) {
      const textColor = App.Studio.utils.readableTextColor(getComputedStyle(bar.fill).backgroundColor);

      App.Studio.utils.replaceInlineDeclarations(bar.label, this.backgroundProperties, declaration);
      App.Studio.utils.setInlineDeclaration(bar.label, "color", textColor);
    }
  },

  fillBackground(bar) {
    return App.Studio.utils.inlineDeclaration(bar.fill, "background")
  }
};
