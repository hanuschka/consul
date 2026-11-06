// YouTube link editing for simple edit mode.
//
// While simple edit mode is on, every YouTube iframe in the block gets a
// control in one layer appended to the block's studio wrapper, outside the
// saved content, so nothing has to be stripped before a save:
// - a video without a real link gets the link form itself, centered over the
//   video, so an empty template asks for its link right away;
// - a video with a link gets a "YouTube-Link bearbeiten" button on its left
//   edge, 15% down from its top, which opens the same form as a popup.
// Observers keep the controls on their videos while the block changes:
// typing, list items added, removed or sorted, resizes, a changed src.
//
// Any common YouTube link is accepted and rewritten to the privacy-friendly
// youtube-nocookie embed. Texts come from the server-rendered popup and
// template, so they follow the locale.
App.Studio.ContentBlocks.SimpleEditMode.YoutubeEdit = {
  buttonInset: 12,
  buttonTopRatio: 0.15,
  blockStates: new Map(),
  iframeByControl: new WeakMap(),
  currentIframe: null,
  currentButton: null,

  initialize() {
    const $document = $(document);

    $document.on("click", ".js-youtube-edit-button", this.handleButtonClick.bind(this));
    $document.on("click", ".js-content-block-accept-youtube-edit", this.acceptEdit.bind(this));
    $document.on("click", ".js-content-block-cancel-youtube-edit", this.cancelEdit.bind(this));
    $document.on("keydown", ".js-content-block-youtube-popup", this.handlePopupKeydown.bind(this));
    $document.on("click", ".js-youtube-inline-form-save", this.handleInlineSave.bind(this));
    $document.on("keydown", ".js-youtube-inline-form-input", this.handleInlineKeydown.bind(this));
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

  getInlineFormTemplate() {
    return document.querySelector(".js-youtube-inline-form-template");
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
      controls: new Map(),
      frameRequest: null,
      scheduleSync: () => this.scheduleSync(contentBlock)
    };

    state.resizeObserver = new ResizeObserver(state.scheduleSync);
    state.resizeObserver.observe(contentBlock);
    state.resizeObserver.observe(wrapper);
    state.mutationObserver = new MutationObserver(state.scheduleSync);
    state.mutationObserver.observe(contentBlock, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["src", "data-src"]
    });
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
  // one sync per frame is enough to keep the controls in place.
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

    state.controls.forEach((control, iframe) => {
      if (iframes.includes(iframe)) return

      control.remove();
      state.controls.delete(iframe);
    });

    // Every rect is read before any control is written, so a sync costs one
    // layout instead of one per video.
    const layerRect = state.layer.getBoundingClientRect();
    const placements = iframes.map((iframe) => ({ iframe: iframe, rect: iframe.getBoundingClientRect() }));
    const labels = this.getLabels();

    placements.forEach((placement) => this.placeControl(state, placement, layerRect, labels));
  },

  placeControl(state, placement, layerRect, labels) {
    const { iframe, rect } = placement;
    const videoSet = this.hasVideo(iframe);
    const control = this.controlFor(state, iframe, videoSet);
    const left = rect.left - layerRect.left;
    const top = rect.top - layerRect.top;

    control.style.display = rect.width > 0 ? "" : "none";

    if (videoSet) {
      control.style.left = `${left + this.buttonInset}px`;
      control.style.top = `${top + rect.height * this.buttonTopRatio}px`;
      this.updateButtonLabel(control, labels.editLabel);
    } else {
      control.style.left = `${left}px`;
      control.style.top = `${top}px`;
      control.style.width = `${rect.width}px`;
      control.style.height = `${rect.height}px`;
    }
  },

  // The form for a video without a link, the button once it has one; a
  // video that changes state gets its control swapped.
  controlFor(state, iframe, videoSet) {
    const existingControl = state.controls.get(iframe);
    const wantsInlineForm = !videoSet;

    if (existingControl && this.isInlineForm(existingControl) === wantsInlineForm) return existingControl

    if (existingControl) {
      existingControl.remove();
    }

    const control = wantsInlineForm ? this.buildInlineForm(state.layer) : this.buildButton(state.layer);

    this.iframeByControl.set(control, iframe);
    state.controls.set(iframe, control);

    return control
  },

  isInlineForm(control) {
    return control.classList.contains("js-youtube-inline-form")
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

  hasVideo(iframe) {
    return Boolean(App.Studio.utils.parseYoutubeUrl(this.iframeUrl(iframe)))
  },

  // With the GDPR two-click setting the URL waits in data-src until consent.
  iframeUrl(iframe) {
    return iframe.getAttribute("src") || iframe.dataset.src || ""
  },

  // A generic video icon on purpose: YouTube's brand rules require their own
  // icon to be at least 100px tall on screens, far larger than a button.
  buildButton(layer) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "studio-edit-button studio-youtube-action studio-youtube-controls--button js-youtube-edit-button";
    button.innerHTML = `
      <i class="fas fa-video" aria-hidden="true"></i>
      <span class="js-youtube-edit-button-label"></span>
    `;

    layer.appendChild(button);

    return button
  },

  buildInlineForm(layer) {
    const form = this.getInlineFormTemplate().content.firstElementChild.cloneNode(true);

    layer.appendChild(form);

    return form
  },

  updateButtonLabel(button, label) {
    const labelElement = button.querySelector(".js-youtube-edit-button-label");

    if (labelElement.textContent !== label) {
      labelElement.textContent = label;
    }
  },

  handleButtonClick(e) {
    e.preventDefault();
    e.stopPropagation();

    this.currentButton = e.currentTarget;
    this.currentIframe = this.iframeByControl.get(this.currentButton);

    this.showPopup();
  },

  showPopup() {
    const input = this.getUrlInput();

    App.Studio.ContentBlocks.SimpleEditMode.EditPopup.show(this.getPopup(), this.currentButton, "below");
    this.hideError();
    input.value = this.iframeUrl(this.currentIframe);
    input.focus();
  },

  acceptEdit(e) {
    e.preventDefault();

    if (!this.applyUrl(this.currentIframe, this.getUrlInput().value)) {
      this.showError();

      return
    }

    this.hidePopup();
  },

  handleInlineSave(e) {
    e.preventDefault();

    this.submitInlineForm(e.currentTarget.closest(".js-youtube-inline-form"));
  },

  handleInlineKeydown(e) {
    if (e.key !== "Enter") return

    e.preventDefault();
    this.submitInlineForm(e.currentTarget.closest(".js-youtube-inline-form"));
  },

  // On success the src change makes the next sync swap this form for the
  // edit button.
  submitInlineForm(form) {
    const input = form.querySelector(".js-youtube-inline-form-input");
    const applied = this.applyUrl(this.iframeByControl.get(form), input.value);

    form.querySelector(".js-youtube-inline-form-error").hidden = applied;

    if (applied) {
      input.removeAttribute("aria-invalid");
    } else {
      input.setAttribute("aria-invalid", "true");
      input.focus();
    }
  },

  applyUrl(iframe, url) {
    const video = App.Studio.utils.parseYoutubeUrl(url);

    if (!video) return false

    this.applyVideo(iframe, App.Studio.utils.youtubeEmbedUrl(video.videoId, video.startSeconds));

    return true
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
