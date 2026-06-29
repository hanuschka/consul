// Height control for map content blocks in simple edit mode.
//
// A map content block renders the map inside
// `<div class="projekt-map-embed js-projekt-map-embed" style="height: Npx">`.
// The fixed height lives as an inline style on that wrapper; the SCSS height
// chain propagates it down to the Leaflet container. Because the wrapper is
// preserved by App.Studio.utils.resetMapEmbeds when the body is persisted
// (only the hydrated .projekt-map-shortcode is stripped), changing the inline
// height and saving the block keeps the new height.
//
// On entering simple edit mode this injects a frosted-glass panel into the
// bottom-left corner of each map embed; on exit it removes it. The panel itself
// must never reach the saved body, so resetMapEmbeds also strips
// .js-map-height-control.
App.Studio.ContentBlocks.SimpleEditMode.MapEdit = {
  controlClass: "js-map-height-control",
  embedSelector: ".js-projekt-map-embed",
  inputSelector: ".js-map-height-input",
  minHeight: 200,
  maxHeight: 900,
  step: 20,
  defaultHeight: 500,

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("input", this.inputSelector, this.handleHeightInput.bind(this))
    $document.on("click", ".js-map-height-decrease", this.handleHeightDecrease.bind(this))
    $document.on("click", ".js-map-height-increase", this.handleHeightIncrease.bind(this))
  },

  toggleMapControls(contentBlock, enabled) {
    const embeds = contentBlock.querySelectorAll(this.embedSelector);

    if (enabled) {
      embeds.forEach((embed) => this.addControlToEmbed(embed))
    } else {
      embeds.forEach((embed) => this.removeControlFromEmbed(embed))
    }
  },

  addControlToEmbed(embed) {
    if (embed.querySelector("." + this.controlClass)) return

    embed.appendChild(this.buildControl(this.currentHeight(embed)))
  },

  removeControlFromEmbed(embed) {
    const control = embed.querySelector("." + this.controlClass)

    if (control) control.remove()
  },

  buildControl(height) {
    const control = document.createElement("div")
    control.className =
      `${this.controlClass} studio-content-block-map-height-control ` +
      "js-studio-hide-on-preview js-content-block-element-not-editable"
    control.contentEditable = false
    control.innerHTML = `
      <span class="studio-content-block-map-height-control--label">
        <i class="fas fa-arrows-alt-v studio-content-block-map-height-control--icon"></i>
        Höhe
      </span>
      <span class="studio-content-block-map-height-control--stepper">
        <button
          type="button"
          class="studio-content-block-map-height-control--step js-map-height-decrease"
          aria-label="Kartenhöhe verringern"
          tabindex="-1"
        >
          <i class="fas fa-minus"></i>
        </button>
        <span class="studio-content-block-map-height-control--value">
          <input
            type="number"
            class="studio-content-block-map-height-control--input js-map-height-input"
            value="${height}"
            min="${this.minHeight}"
            max="${this.maxHeight}"
            step="${this.step}"
            aria-label="Kartenhöhe in Pixel"
          >
          <span class="studio-content-block-map-height-control--unit">px</span>
        </span>
        <button
          type="button"
          class="studio-content-block-map-height-control--step js-map-height-increase"
          aria-label="Kartenhöhe vergrößern"
          tabindex="-1"
        >
          <i class="fas fa-plus"></i>
        </button>
      </span>
    `

    return control
  },

  currentHeight(embed) {
    const inlineHeight = parseInt(embed.style.height)

    if (!isNaN(inlineHeight)) return inlineHeight

    const measuredHeight = Math.round(embed.getBoundingClientRect().height)

    if (measuredHeight > 0) return measuredHeight

    return this.defaultHeight
  },

  getEmbedFromControl(element) {
    return element.closest(this.embedSelector);
  },

  handleHeightInput(e) {
    const input = e.currentTarget;
    const embed = this.getEmbedFromControl(input);

    if (!embed) return

    const height = this.clampHeight(parseInt(input.value));

    if (isNaN(height)) return

    this.applyHeight(embed, height);
  },

  handleHeightDecrease(e) {
    e.preventDefault();

    this.stepHeight(e.currentTarget, -1);
  },

  handleHeightIncrease(e) {
    e.preventDefault();

    this.stepHeight(e.currentTarget, 1);
  },

  stepHeight(button, direction) {
    const embed = this.getEmbedFromControl(button);

    if (!embed) return

    const input = embed.querySelector(this.inputSelector);
    const current = this.currentHeight(embed);
    const next = this.clampHeight(current + (direction * this.step));

    if (next === current) return

    input.value = next;
    this.applyHeight(embed, next);
  },

  clampHeight(height) {
    if (isNaN(height)) return height

    return Math.min(this.maxHeight, Math.max(this.minHeight, height));
  },

  applyHeight(embed, height) {
    embed.style.height = `${height}px`;

    if (App.Map && App.Map.invalidateSizeIn) {
      App.Map.invalidateSizeIn(embed);
    }
  },
}
