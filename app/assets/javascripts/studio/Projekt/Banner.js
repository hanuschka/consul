App.Studio.Projekt.Banner = {
  initialized: false,
  COUNTER_VISIBILITY_THRESHOLD: 55,
  GENERATION_POLL_INTERVAL: 3000,
  GENERATION_POLL_MAX_ATTEMPTS: 100,

  // Mirror of MultilineSubtitleNormalizer regexes (lib/multiline_subtitle_normalizer.rb).
  // Kept in sync as a defense-in-depth pre-clean for pasted text before it hits the backend.
  INVISIBLE_CHARS_REGEX: /[\u200B-\u200F\u202A-\u202E\u2060-\u206F\uFEFF\u180E]/g,
  CONTROL_CHARS_REGEX: /[\u0000-\u0008\u000B-\u001F\u007F-\u009F]/g,
  NON_BREAKING_SPACE_REGEX: /\u00A0/g,

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-projekt-banner-text-edit-button", this.turnOnTextEdit.bind(this));
    $document.on("click", ".js-projekt-banner--text-edit-cancel", this.cancelTextEdit.bind(this));
    $document.on("click", ".js-projekt-banner--text-edit-save", this.saveEditedText.bind(this));
    $document.on("paste", ".js-projekt-banner--edit-field-content [contenteditable]", this.handlePaste.bind(this));
    $document.on("input", ".js-projekt-banner--edit-field-content [contenteditable]", this.handleInput.bind(this));
    $document.on("change", ".js-projekt-banner--image-upload-input", this.updateTitleImage.bind(this));
    $document.on("click", ".js-projekt-banner--image-delete-button", this.deleteTitleImage.bind(this));
    $document.on("click", ".js-projekt-banner--image-generate-button", this.openGenerateImageModal.bind(this));
    $document.on("click", ".js-projekt-banner-generate-submit", this.submitGenerateImage.bind(this));
    $document.on("click", ".js-projekt-banner--ai-marker-button", this.toggleAiMarker.bind(this));
  },

  turnOnTextEdit(e) {
    const { container, field } = this.getFieldElementsForButton(e.currentTarget)

    container.classList.add("-text-edit-mode")
    container.dataset.originalFieldHtml = field.innerHTML.trim();

    field.firstElementChild.contentEditable = "plaintext-only"
    App.Studio.utils.focusContentEditableElement(field.firstElementChild)

    this.updateCharCounter(container, field)
  },

  cancelTextEdit(e) {
    const { container, field } = this.getFieldElementsForButton(e.currentTarget)

    container.classList.remove("-text-edit-mode", "-over-limit")
    field.firstElementChild.contentEditable = false
    field.innerHTML = container.dataset.originalFieldHtml;
  },

  getFieldElementsForButton(button) {
    const container = button.closest(".js-projekt-banner--edit-field-container")
    const field = container.querySelector(".js-projekt-banner--edit-field-content")

    return { button, container, field }
  },

  getFieldElementsFromContent(contentEditableEl) {
    const container = contentEditableEl.closest(".js-projekt-banner--edit-field-container")
    const field = container.querySelector(".js-projekt-banner--edit-field-content")

    return { container, field }
  },

  saveEditedText(e) {
    const { container, field } = this.getFieldElementsForButton(e.currentTarget)

    if (!container.classList.contains("-text-edit-mode")) return
    if (container.classList.contains("-over-limit")) return

    const allowBrTags = container.dataset.allowBrTags === "true"
    const plainText = this.readPlainText(field, allowBrTags)

    container.classList.remove("-text-edit-mode")
    field.firstElementChild.contentEditable = false
    container.dataset.originalFieldHtml = ""

    if (plainText) this.renderPlainTextToField(field, plainText, allowBrTags)

    App.Ajax
      .request({
        url: container.dataset.updateUrl,
        method: "PATCH",
        data: {
          kind: container.dataset.kind,
          attribute: container.dataset.attribute,
          [container.dataset.fieldName]: plainText
        }
      })
  },

  // Read editor content as plain text. Walk the tree because innerText is
  // CSS-aware and can lose content during state transitions (e.g. when
  // contentEditable flips from "plaintext-only" to false the browser may
  // strip placeholder nodes or recompute layout). textContent ignores <br>
  // line breaks. Manual walk is robust to both cases.
  readPlainText(field, allowBrTags) {
    const target = field.firstElementChild

    if (!target) return ""

    if (!allowBrTags) return (target.textContent || "").replace(/\s+/g, " ").trim()

    return this.extractTextWithLineBreaks(target).replace(/\r\n|\r/g, "\n").trim()
  },

  // Concatenate text nodes; insert "\n" for <br> and at boundaries of block
  // elements (Chrome wraps Enter-inserted lines in <div>, Firefox in <p>).
  extractTextWithLineBreaks(root) {
    const blockTags = /^(?:DIV|P|LI|H[1-6]|ARTICLE|SECTION|BLOCKQUOTE|TR|PRE)$/

    let out = ""

    const walk = (node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        out += node.textContent
        return
      }

      if (node.nodeType !== Node.ELEMENT_NODE) return

      if (node.tagName === "BR") {
        out += "\n"
        return
      }

      const isBlock = node !== root && blockTags.test(node.tagName)

      if (isBlock && out && !out.endsWith("\n")) out += "\n"

      node.childNodes.forEach(walk)

      if (isBlock && !out.endsWith("\n")) out += "\n"
    }

    walk(root)
    return out
  },

  // Render plain text back into the field as text nodes joined by <br> elements.
  // Avoids innerHTML so untrusted content can never be interpreted as markup.
  renderPlainTextToField(field, text, allowBrTags) {
    const target = field.firstElementChild

    target.textContent = ""

    if (!allowBrTags) {
      target.appendChild(document.createTextNode(text))
      return
    }

    const lines = text.split("\n")
    lines.forEach((line, index) => {
      if (index > 0) target.appendChild(document.createElement("br"))
      target.appendChild(document.createTextNode(line))
    })
  },

  handlePaste(e) {
    const contentEditableEl = e.currentTarget || e.target
    const { container } = this.getFieldElementsFromContent(contentEditableEl)
    const allowBrTags = container.dataset.allowBrTags === "true"

    e.preventDefault()

    const clipboard = (e.originalEvent || e).clipboardData
    if (!clipboard) return

    const raw = clipboard.getData("text/plain") || ""
    const cleaned = this.cleanPastedText(raw, allowBrTags)

    if (!cleaned) return

    document.execCommand("insertText", false, cleaned)
  },

  cleanPastedText(text, allowBrTags) {
    let out = text
      .normalize("NFC")
      .replace(this.INVISIBLE_CHARS_REGEX, "")
      .replace(this.CONTROL_CHARS_REGEX, "")
      .replace(this.NON_BREAKING_SPACE_REGEX, " ")

    if (allowBrTags) {
      out = out.replace(/\r\n|\r/g, "\n")
    }
    else {
      out = out.replace(/\s+/g, " ")
    }

    return out
  },

  handleInput(e) {
    const contentEditableEl = e.currentTarget || e.target
    const { container, field } = this.getFieldElementsFromContent(contentEditableEl)
    this.updateCharCounter(container, field)
  },

  updateCharCounter(container, field) {
    const counter = container.querySelector(".js-projekt-banner-edit-field--char-counter")

    if (!counter) return

    const maxLength = parseInt(container.dataset.maxVisibleLength, 10)
    const maxLineBreaks = parseInt(container.dataset.maxLineBreaks, 10)
    const allowBrTags = container.dataset.allowBrTags === "true"
    const plainText = this.readPlainText(field, allowBrTags)
    const visibleLength = Array.from(plainText.replace(/\n/g, "")).length
    const lineBreaks = allowBrTags ? (plainText.match(/\n/g) || []).length : 0

    const currentEl = counter.querySelector(".js-projekt-banner-edit-field--char-counter-current")

    if (currentEl) currentEl.textContent = visibleLength

    const overLength = Number.isFinite(maxLength) && visibleLength > maxLength
    const overLines = Number.isFinite(maxLineBreaks) && lineBreaks > maxLineBreaks

    container.classList.toggle("-over-limit", overLength || overLines)
    container.classList.toggle("-counter-visible", visibleLength > this.COUNTER_VISIBILITY_THRESHOLD)
  },

  async updateTitleImage(e) {
    const fileInput = e.currentTarget;
    const file = fileInput.files[0];
    const container = fileInput.closest(".js-projekt-image-uploader")

    if (!file) return

    const imagePreview = container.querySelector(".js-projekt-image-upload-preview")
    const previewUrl = URL.createObjectURL(file)

    this.clearUploadError(container)

    imagePreview.src = previewUrl
    imagePreview.classList.add("-image-set")

    this.showUploadProgress(container)

    const formData = new FormData();
    formData.append("file", file);

    App.Ajax
      .request({
        url: container.dataset.updateUrl,
        method: "PATCH",
        processData: false,
        contentType: false,
        data: formData
      })
      .then(() => {
        this.setUploadProgressMessage(container, "processing")
        this.handleUploadSuccess(container, imagePreview, previewUrl)
      })
      .catch((xhr) => {
        this.handleUploadError(container, imagePreview, previewUrl, xhr)
      })
      .always(() => {
        this.hideUploadProgress(container)
      })
  },

  showUploadProgress(container) {
    const overlay = container.querySelector(".js-projekt-banner-upload-progress")

    if (!overlay) return

    this.setUploadProgressMessage(container, "uploading")
    overlay.hidden = false
  },

  hideUploadProgress(container) {
    const overlay = container.querySelector(".js-projekt-banner-upload-progress")

    if (!overlay) return

    overlay.hidden = true
  },

  setUploadProgressMessage(container, state) {
    const message = container.querySelector(".js-projekt-banner-upload-progress-message")

    if (!message) return

    const texts = {
      uploading: message.dataset.uploadingText,
      processing: message.dataset.processingText,
      generating: message.dataset.generatingText
    }
    const text = texts[state] || message.dataset.uploadingText

    if (text) message.textContent = text
  },

  handleUploadSuccess(container, imagePreview, previewUrl) {
    const { mainImage, blurImage } = this.resolveResourceImageEls(container)

    if (mainImage && blurImage) {
      this.swapResourceImageSrc(mainImage, blurImage, imagePreview, previewUrl)
    }

    const glightbox = container.querySelector("a.glightbox");
    if (glightbox) glightbox.setAttribute("href", previewUrl);

    this.setAiMarkerGeneratedInApp(container, false);
    this.toggleImageActionButtons(container, true);
    this.applyAiMarkerState(container, false);

    if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
  },

  toggleImageActionButtons(container, imagePresent) {
    const deleteButton = container.querySelector(".js-projekt-banner--image-delete-button");
    const aiMarkerButton = container.querySelector(".js-projekt-banner--ai-marker-button");

    // The generate button stays visible whether or not an image is set, so an
    // existing banner can be regenerated; the delete button and the AI marker
    // both need a picture to act on.
    if (deleteButton) deleteButton.classList.toggle("d-none", !imagePresent);

    if (aiMarkerButton) {
      const generatedInApp = aiMarkerButton.dataset.aiGeneratedInApp === "true";

      aiMarkerButton.classList.toggle("d-none", !imagePresent || generatedInApp);
    }
  },

  // A banner the app generated is marked at attach time, so there is nothing
  // for the admin to declare or revoke and the marker button has no job left.
  setAiMarkerGeneratedInApp(container, generatedInApp) {
    const button = container.querySelector(".js-projekt-banner--ai-marker-button");

    if (button) button.dataset.aiGeneratedInApp = String(generatedInApp);
  },

  async toggleAiMarker(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const container = button.closest(".js-projekt-image-uploader");
    if (!container) return;

    const nextState = button.getAttribute("aria-pressed") !== "true";

    button.disabled = true;
    this.clearUploadError(container);

    try {
      await App.Ajax.request({
        url: container.dataset.aiGeneratedUrl,
        method: "PATCH",
        dataType: "json",
        data: { ai_generated: nextState }
      });

      this.applyAiMarkerState(container, nextState);
    } catch (xhr) {
      // The banner may have been deleted in another session, in which case the
      // marker has nothing to attach to -- say so instead of leaving the button
      // silently showing the old state.
      this.showUploadError(container, this.errorText(container, "aiMarkerFailedText"));
    } finally {
      button.disabled = false;
    }
  },

  errorText(container, datasetKey) {
    const messageElement = container.querySelector(".js-projekt-banner-upload-error-message");

    return messageElement ? messageElement.dataset[datasetKey] : "";
  },

  // Reflects what the server just decided: generating a banner marks it,
  // uploading or deleting one leaves nothing marked
  // (Image#clear_generated_flags_on_replaced_attachment).
  applyAiMarkerState(container, aiGenerated) {
    const button = container.querySelector(".js-projekt-banner--ai-marker-button");

    if (button) {
      button.setAttribute("aria-pressed", String(aiGenerated));
      button.classList.toggle("-active", aiGenerated);
    }

    const resourceImage = container.querySelector(".resource-image");
    if (!resourceImage) return;

    const existingLabel = resourceImage.querySelector(".ai-image-label-tooltip");
    if (existingLabel) existingLabel.remove();

    if (!aiGenerated) return;

    const template = container.querySelector(".js-projekt-banner--ai-label-template");
    if (!template) return;

    resourceImage.appendChild(template.content.cloneNode(true));
  },

  handleUploadError(container, imagePreview, previewUrl, xhr) {
    imagePreview.classList.remove("-image-set")
    imagePreview.src = ""
    URL.revokeObjectURL(previewUrl)

    this.showUploadError(container, this.extractUploadErrorMessage(container, xhr))
  },

  extractUploadErrorMessage(container, xhr) {
    const response = xhr && xhr.responseJSON

    if (response && response.errors && response.errors.length > 0) return response.errors.join(" ")

    return this.errorText(container, "fallbackText")
  },

  showUploadError(container, message) {
    const errorElement = container.querySelector(".js-projekt-banner-upload-error")
    const messageElement = container.querySelector(".js-projekt-banner-upload-error-message")

    if (!errorElement || !messageElement) return

    messageElement.textContent = message
    errorElement.hidden = false
  },

  clearUploadError(container) {
    const errorElement = container.querySelector(".js-projekt-banner-upload-error")

    if (!errorElement) return

    errorElement.hidden = true
  },

  resolveResourceImageEls(container) {
    let mainImage = container.querySelector(".resource-image--main");
    let blurImage = container.querySelector(".resource-image--blur");

    if (mainImage && blurImage) return { mainImage, blurImage }

    const resourceImage = container.querySelector(".resource-image");
    if (!resourceImage) return { mainImage: null, blurImage: null }

    resourceImage.innerHTML =
      `<img class="resource-image--main" alt="">` +
      `<img class="resource-image--blur" aria-hidden="true">`;

    return {
      mainImage: resourceImage.querySelector(".resource-image--main"),
      blurImage: resourceImage.querySelector(".resource-image--blur")
    }
  },

  swapResourceImageSrc(mainImage, blurImage, imagePreview, previewUrl) {
    mainImage.addEventListener("load", () => {
      imagePreview.classList.remove("-image-set");
      imagePreview.src = "";
    }, { once: true });

    this.applyResourceImageSrc(mainImage, blurImage, previewUrl);
  },

  applyResourceImageSrc(mainImage, blurImage, imageUrl) {
    mainImage.style.width = "100%";
    mainImage.style.height = "100%";
    mainImage.style.objectFit = "cover";

    mainImage.removeAttribute("srcset");
    mainImage.removeAttribute("sizes");
    blurImage.removeAttribute("srcset");
    blurImage.removeAttribute("sizes");

    mainImage.src = imageUrl;
    blurImage.src = imageUrl;
  },

  async deleteTitleImage(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const container = button.closest(".js-projekt-image-uploader");
    if (!container) return;

    const confirmMessage = container.dataset.deleteConfirm;
    if (confirmMessage && !window.confirm(confirmMessage)) return;

    await App.Ajax.request({
      url: container.dataset.deleteUrl,
      method: "DELETE"
    });

    const resourceImage = container.querySelector(".resource-image");
    if (resourceImage) {
      const iconClass = container.dataset.placeholderIconClass || "fa-image";
      const ariaLabel = container.dataset.placeholderAriaLabel || "";
      const hint = container.dataset.placeholderHint || "";
      const hintHtml = hint
        ? `<div class="resource-image--missing-image-placeholder-hint">${hint}</div>`
        : "";
      resourceImage.innerHTML =
        `<div class="resource-image--missing-image-placeholder" role="img" aria-label="${ariaLabel}">` +
          `<i class="resource-image--missing-image-placeholder-icon fa ${iconClass}" aria-hidden="true"></i>` +
          hintHtml +
        `</div>`;
    }

    const glightbox = container.querySelector("a.glightbox");
    if (glightbox) glightbox.removeAttribute("href");

    this.setAiMarkerGeneratedInApp(container, false);
    this.toggleImageActionButtons(container, false);
    this.applyAiMarkerState(container, false);

    if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
  },

  openGenerateImageModal(e) {
    e.preventDefault();

    App.SharedModal.open("projektBannerImageGenerateModal");
    setTimeout(() => {
      $(".js-projekt-banner-generate-prompt").trigger("focus");
    }, 200);
  },

  submitGenerateImage(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const container = button.closest(".js-projekt-image-uploader");
    if (!container) return;

    const prompt = container.querySelector(".js-projekt-banner-generate-prompt").value.trim();
    const useContentCheckbox = container.querySelector(".js-projekt-banner-generate-use-content");
    const useContent = useContentCheckbox ? useContentCheckbox.checked : false;

    App.SharedModal.closeById("projektBannerImageGenerateModal");

    this.startImageGeneration(container, { prompt: prompt, use_projekt_content: useContent });
  },

  startImageGeneration(container, payload) {
    const generateButton = container.querySelector(".js-projekt-banner--image-generate-button");
    if (generateButton) generateButton.disabled = true;

    this.clearUploadError(container);
    this.showGenerationProgress(container);

    App.Ajax
      .request({
        url: container.dataset.generateUrl,
        method: "POST",
        dataType: "json",
        data: payload
      })
      .then(() => {
        this.pollGenerationStatus(container, 0);
      })
      .catch(() => {
        this.handleGenerationError(container);
      });
  },

  showGenerationProgress(container) {
    const overlay = container.querySelector(".js-projekt-banner-upload-progress");

    if (!overlay) return

    // With no banner yet, the only thing behind the overlay is the empty-state
    // icon and its hint, which the backdrop blur smears rather than hides.
    const bannerPresent = !!container.querySelector(".resource-image--main");
    overlay.classList.toggle("-flat-ground", !bannerPresent);

    this.setUploadProgressMessage(container, "generating");
    overlay.hidden = false;
  },

  pollGenerationStatus(container, attempts) {
    if (attempts >= this.GENERATION_POLL_MAX_ATTEMPTS) {
      this.handleGenerationError(container);
      return
    }

    App.Ajax
      .request({
        url: container.dataset.generateStatusUrl,
        method: "GET",
        dataType: "json"
      })
      .then((response) => this.handleGenerationStatus(container, response, attempts))
      .catch(() => this.scheduleNextGenerationPoll(container, attempts));
  },

  scheduleNextGenerationPoll(container, attempts) {
    setTimeout(() => this.pollGenerationStatus(container, attempts + 1), this.GENERATION_POLL_INTERVAL);
  },

  handleGenerationStatus(container, response, attempts) {
    if (response.status === "completed" && response.image_url) {
      this.handleGenerationSuccess(container, response.image_url);
    }
    else if (response.status === "failed") {
      this.handleGenerationError(container);
    }
    else {
      this.scheduleNextGenerationPoll(container, attempts);
    }
  },

  handleGenerationSuccess(container, imageUrl) {
    const { mainImage, blurImage } = this.resolveResourceImageEls(container);

    if (mainImage && blurImage) {
      this.applyResourceImageSrc(mainImage, blurImage, imageUrl);
    }

    const glightbox = container.querySelector("a.glightbox");
    if (glightbox) glightbox.setAttribute("href", imageUrl);

    this.hideUploadProgress(container);
    this.resetGenerateButton(container);
    this.setAiMarkerGeneratedInApp(container, true);
    this.toggleImageActionButtons(container, true);
    this.applyAiMarkerState(container, true);

    if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
  },

  handleGenerationError(container) {
    this.hideUploadProgress(container);
    this.resetGenerateButton(container);
    this.showUploadError(container, this.generationErrorMessage(container));
  },

  resetGenerateButton(container) {
    const generateButton = container.querySelector(".js-projekt-banner--image-generate-button");

    if (generateButton) generateButton.disabled = false;
  },

  generationErrorMessage(container) {
    return this.errorText(container, "generateFailedText");
  }
};
