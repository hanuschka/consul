// "YouTube-Link hinzufügen / bearbeiten" buttons for simple edit mode.
//
// Every YouTube iframe in the block gets a button at its top-left corner for
// as long as simple edit mode is on. The buttons live in one layer appended
// to the block's studio wrapper, outside the saved content, so nothing has to
// be stripped before a save. Observers keep them on their videos while the
// block changes: typing, list items added, removed or sorted, resizes.
//
// The button opens a popup that takes any common YouTube link and rewrites
// the iframe to the privacy-friendly youtube-nocookie embed. Labels come from
// the server-rendered popup, so they follow the locale.
App.Studio.ContentBlocks.SimpleEditMode.YoutubeEdit = {
  buttonInset: 12,
  blockStates: new Map(),
  iframeByButton: new WeakMap(),
  currentIframe: null,
  currentButton: null,

  initialize() {
    const $document = $(document);

    $document.on("click", ".js-youtube-edit-button", this.handleButtonClick.bind(this));
    $document.on("click", ".js-content-block-accept-youtube-edit", this.acceptEdit.bind(this));
    $document.on("click", ".js-content-block-cancel-youtube-edit", this.cancelEdit.bind(this));
    $document.on("keydown", ".js-content-block-youtube-popup", this.handlePopupKeydown.bind(this));
  },

  getPopup() {
    return $(".js-content-block-youtube-popup");
  },

  getUrlInput() {
    return document.querySelector(".js-content-block-youtube-url-input");
  },

  getErrorElement() {
    return document.querySelector(".js-content-block-youtube-url-error");
  },

  getLabels() {
    return document.querySelector(".js-content-block-youtube-popup-labels").dataset;
  },

  toggleYoutubeControls(contentBlock, enabled) {
    if (enabled) {
      this.enableControls(contentBlock);
    } else {
      this.disableControls(contentBlock);
    }
  },

  enableControls(contentBlock) {
    if (this.blockStates.has(contentBlock)) return

    const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(contentBlock);
    const layer = document.createElement("div");
    layer.className = "studio-youtube-controls js-youtube-controls js-studio-hide-on-preview";
    wrapper.appendChild(layer);

    const state = {
      layer: layer,
      buttons: new Map(),
      frameRequest: null,
      scheduleSync: () => this.scheduleSync(contentBlock)
    };

    state.resizeObserver = new ResizeObserver(state.scheduleSync);
    state.resizeObserver.observe(contentBlock);
    state.resizeObserver.observe(wrapper);
    state.mutationObserver = new MutationObserver(state.scheduleSync);
    state.mutationObserver.observe(contentBlock, { childList: true, subtree: true });
    window.addEventListener("resize", state.scheduleSync);

    this.blockStates.set(contentBlock, state);
    this.syncControls(contentBlock);
  },

  disableControls(contentBlock) {
    const state = this.blockStates.get(contentBlock);

    if (!state) return

    state.resizeObserver.disconnect();
    state.mutationObserver.disconnect();
    window.removeEventListener("resize", state.scheduleSync);
    cancelAnimationFrame(state.frameRequest);
    state.layer.remove();
    this.blockStates.delete(contentBlock);

    if (this.currentIframe && contentBlock.contains(this.currentIframe)) {
      this.hidePopup();
    }
  },

  // Observers fire in bursts (one per typed character, several per sort);
  // one sync per frame is enough to keep the buttons in place.
  // A block deleted while in simple edit mode never gets its toggle-off call,
  // so its observers and resize listener are dropped here instead.
  scheduleSync(contentBlock) {
    const state = this.blockStates.get(contentBlock);

    if (!state || state.frameRequest) return

    if (!contentBlock.isConnected) {
      this.disableControls(contentBlock);

      return
    }

    state.frameRequest = requestAnimationFrame(() => {
      state.frameRequest = null;
      this.syncControls(contentBlock);
    });
  },

  syncControls(contentBlock) {
    const state = this.blockStates.get(contentBlock);
    const iframes = this.youtubeIframesIn(contentBlock);

    state.buttons.forEach((button, iframe) => {
      if (iframes.includes(iframe)) return

      button.remove();
      state.buttons.delete(iframe);
    });

    // Every rect is read before any button is written, so a sync costs one
    // layout instead of one per video.
    const layerRect = state.layer.getBoundingClientRect();
    const placements = iframes.map((iframe) => ({ iframe: iframe, rect: iframe.getBoundingClientRect() }));
    const labels = this.getLabels();

    placements.forEach((placement) => this.placeButton(state, placement, layerRect, labels));
  },

  placeButton(state, placement, layerRect, labels) {
    const { iframe, rect } = placement;

    if (!state.buttons.has(iframe)) {
      state.buttons.set(iframe, this.buildButton(state.layer, iframe));
    }

    const button = state.buttons.get(iframe);

    button.style.display = rect.width > 0 ? "" : "none";
    button.style.left = `${rect.left - layerRect.left + this.buttonInset}px`;
    button.style.top = `${rect.top - layerRect.top + this.buttonInset}px`;
    this.updateButtonState(button, iframe, labels);
  },

  youtubeIframesIn(contentBlock) {
    return Array
      .from(contentBlock.querySelectorAll("iframe"))
      .filter((iframe) => this.isEditableYoutubeIframe(iframe));
  },

  isEditableYoutubeIframe(iframe) {
    if (iframe.closest(".js-content-block-element-not-editable")) return false

    return App.Studio.utils.isYoutubeEmbed(this.iframeUrl(iframe))
  },

  // With the GDPR two-click setting the URL waits in data-src until consent.
  iframeUrl(iframe) {
    return iframe.getAttribute("src") || iframe.dataset.src || ""
  },

  buildButton(layer, iframe) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "studio-edit-button studio-youtube-controls--button js-youtube-edit-button";
    button.innerHTML = `
      <i class="fab fa-youtube" aria-hidden="true"></i>
      <span class="js-youtube-edit-button-label"></span>
    `;

    this.iframeByButton.set(button, iframe);
    layer.appendChild(button);

    return button
  },

  updateButtonState(button, iframe, labels) {
    const videoSet = Boolean(App.Studio.utils.parseYoutubeUrl(this.iframeUrl(iframe)));
    const labelElement = button.querySelector(".js-youtube-edit-button-label");
    const label = videoSet ? labels.editLabel : labels.addLabel;

    button.classList.toggle("-green", !videoSet);

    if (labelElement.textContent !== label) {
      labelElement.textContent = label;
    }
  },

  handleButtonClick(e) {
    e.preventDefault();
    e.stopPropagation();

    this.currentButton = e.currentTarget;
    this.currentIframe = this.iframeByButton.get(this.currentButton);

    this.showPopup();
  },

  showPopup() {
    const input = this.getUrlInput();
    const currentUrl = this.iframeUrl(this.currentIframe);

    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show(this.getPopup(), this.currentButton, "below");
    this.hideError();
    input.value = App.Studio.utils.parseYoutubeUrl(currentUrl) ? currentUrl : "";
    input.focus();
  },

  acceptEdit(e) {
    e.preventDefault();

    const video = App.Studio.utils.parseYoutubeUrl(this.getUrlInput().value);

    if (!video) {
      this.showError();

      return
    }

    this.applyVideo(this.currentIframe, App.Studio.utils.youtubeEmbedUrl(video.videoId, video.startSeconds));
    this.updateButtonState(this.currentButton, this.currentIframe, this.getLabels());
    this.hidePopup();
  },

  applyVideo(iframe, embedUrl) {
    iframe.setAttribute("src", embedUrl);

    if (iframe.hasAttribute("data-src")) {
      iframe.setAttribute("data-src", embedUrl);
    }

    this.revealConsentWrappedIframe(iframe);
  },

  // The two-click consent overlay would cover the video the editor just set.
  revealConsentWrappedIframe(iframe) {
    const consentWrapper = iframe.closest(".js-iframe-consent-wrapper");

    if (!consentWrapper) return

    $(consentWrapper).find(".js-iframe-consent-explainer").hide();
  },

  cancelEdit(e) {
    e.preventDefault();

    this.hidePopup();
  },

  handlePopupKeydown(e) {
    if (e.key === "Escape") {
      e.preventDefault();
      e.stopPropagation();
      this.hidePopup();

      return
    }

    if (e.key === "Enter" && e.target === this.getUrlInput()) {
      this.acceptEdit(e);
    }
  },

  showError() {
    const input = this.getUrlInput();

    this.getErrorElement().hidden = false;
    input.setAttribute("aria-invalid", "true");
    input.focus();
  },

  hideError() {
    this.getErrorElement().hidden = true;
    this.getUrlInput().removeAttribute("aria-invalid");
  },

  hidePopup() {
    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.hide(this.getPopup());
    this.getUrlInput().value = "";
    this.hideError();
    this.currentIframe = null;
    this.currentButton = null;
  }
};
