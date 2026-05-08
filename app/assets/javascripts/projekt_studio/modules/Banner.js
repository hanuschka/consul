ProjektStudio.Banner = {
  initialized: false,
  COUNTER_VISIBILITY_THRESHOLD: 55,

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
  },

  turnOnTextEdit(e) {
    const { container, field } = this.getFieldElementsForButton(e.currentTarget)

    container.classList.add("-text-edit-mode")
    container.dataset.originalFieldHtml = field.innerHTML.trim();

    field.firstElementChild.contentEditable = "plaintext-only"
    ProjektStudio.utils.focusContentEditableElement(field.firstElementChild)

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

    imagePreview.src = previewUrl
    imagePreview.classList.add("-image-set")

    this.showUploadProgress(container)

    const formData = new FormData();
    formData.append("kind", container.dataset.kind);
    formData.append("attribute", container.dataset.attribute);
    formData.append(container.dataset.fieldName, file);

    App.Ajax
      .request({
        url: container.dataset.updateUrl,
        method: "PATCH",
        processData: false,
        contentType: false,
        data: formData,
        xhr: () => this.buildUploadXhr(container)
      })
      .then(() => {
        this.handleUploadSuccess(container, imagePreview, previewUrl)
      })
      .always(() => {
        this.hideUploadProgress(container)
      })
  },

  buildUploadXhr(container) {
    const xhr = new XMLHttpRequest();

    xhr.upload.addEventListener("progress", (event) => {
      this.handleUploadProgressEvent(container, event)
    });

    return xhr;
  },

  handleUploadProgressEvent(container, event) {
    if (!event.lengthComputable) return

    const percent = Math.min(100, Math.round((event.loaded / event.total) * 100))
    this.setUploadProgress(container, percent)
  },

  showUploadProgress(container) {
    const overlay = container.querySelector(".js-projekt-banner-upload-progress")

    if (!overlay) return

    this.setUploadProgress(container, 0)
    overlay.hidden = false
  },

  hideUploadProgress(container) {
    const overlay = container.querySelector(".js-projekt-banner-upload-progress")

    if (!overlay) return

    overlay.hidden = true
    this.setUploadProgress(container, 0)
  },

  setUploadProgress(container, percent) {
    const ring = container.querySelector(".js-projekt-banner-upload-progress-ring")
    const label = container.querySelector(".js-projekt-banner-upload-progress-percent")

    if (ring) ring.style.setProperty("--upload-progress", percent)
    if (label) label.textContent = `${percent}%`

    this.setUploadProgressMessage(container, percent >= 100 ? "processing" : "uploading")
  },

  setUploadProgressMessage(container, state) {
    const message = container.querySelector(".js-projekt-banner-upload-progress-message")

    if (!message) return

    const text = state === "processing"
      ? message.dataset.processingText
      : message.dataset.uploadingText

    if (text) message.textContent = text
  },

  handleUploadSuccess(container, imagePreview, previewUrl) {
    const { mainImage, blurImage } = this.resolveResourceImageEls(container)

    if (mainImage && blurImage) {
      this.swapResourceImageSrc(mainImage, blurImage, imagePreview, previewUrl)
    }

    const glightbox = container.querySelector("a.glightbox");
    if (glightbox) glightbox.setAttribute("href", previewUrl);

    const deleteButton = container.querySelector(".js-projekt-banner--image-delete-button");
    if (deleteButton) deleteButton.classList.remove("d-none");

    if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
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

    mainImage.style.width = "100%";
    mainImage.style.height = "100%";
    mainImage.style.objectFit = "cover";

    mainImage.removeAttribute("srcset");
    mainImage.removeAttribute("sizes");
    blurImage.removeAttribute("srcset");
    blurImage.removeAttribute("sizes");

    mainImage.src = previewUrl;
    blurImage.src = previewUrl;
  },

  async deleteTitleImage(e) {
    e.preventDefault();

    const button = e.currentTarget;
    const container = button.closest(".js-projekt-image-uploader");
    if (!container) return;

    const confirmMessage = container.dataset.deleteConfirm;
    if (confirmMessage && !window.confirm(confirmMessage)) return;

    const formData = new FormData();
    formData.append("kind", container.dataset.kind);
    formData.append("attribute", container.dataset.attribute);
    formData.append("remove_attachment", "1");

    await App.Ajax.request({
      url: container.dataset.updateUrl,
      method: "PATCH",
      processData: false,
      contentType: false,
      data: formData
    });

    const resourceImage = container.querySelector(".resource-image");
    if (resourceImage) {
      const iconClass = container.dataset.placeholderIconClass || "fa-image";
      const ariaLabel = container.dataset.placeholderAriaLabel || "";
      resourceImage.innerHTML =
        `<div class="resource-image--missing-image-placeholder" role="img" aria-label="${ariaLabel}">` +
          `<i class="resource-image--missing-image-placeholder-icon fa ${iconClass}" aria-hidden="true"></i>` +
        `</div>`;
    }

    const glightbox = container.querySelector("a.glightbox");
    if (glightbox) glightbox.removeAttribute("href");

    button.classList.add("d-none");

    if (typeof App !== "undefined" && App.ImageGallery) App.ImageGallery.initialize();
  }
};
