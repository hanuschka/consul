(function() {
  "use strict";

  App.ImageCropper = {
    MODAL_ID: "image-cropper-modal",
    OUTPUT_MAX_DIMENSION: 2400,
    JPEG_QUALITY: 0.92,

    initialize: function() {
      this.boundModalClose = this.handleModalClose.bind(this);
      this.boundSelectionChange = this.handleSelectionChange.bind(this);
      this.boundImageTransform = this.handleImageTransform.bind(this);
      this.reset();
      this.bindEvents();
    },

    bindEvents: function() {
      $(document)
        .off("click.imageCropper")
        .on("click.imageCropper", ".js-image-cropper--confirm", this.handleConfirm.bind(this))
        .on("click.imageCropper", ".js-image-cropper--cancel", this.handleCancel.bind(this));
    },

    // Public API. Opens the crop modal for `file` and invokes options.onConfirm
    // with the cropped File when confirmed, or options.onCancel when dismissed.
    open: function(file, options) {
      this.onConfirm = options.onConfirm;
      this.onCancel = options.onCancel;
      this.aspectRatio = options.aspectRatio;
      this.fileName = file.name;
      this.fileType = file.type;
      this.settled = false;

      this.loadImageIntoModal(file);
    },

    loadImageIntoModal: function(file) {
      this.revokeObjectUrl();
      this.objectUrl = URL.createObjectURL(file);

      this.bindModalCloseHandler();
      App.SharedModal.open(this.MODAL_ID);
      this.startCropper();
    },

    // The <cropper-*> elements measure themselves against their container, so
    // the source is only assigned after the dialog is visible — otherwise the
    // image is laid out inside a zero-sized canvas.
    startCropper: function() {
      const elements = this.getCropperElements();
      const selection = elements.selection;

      selection.aspectRatio = this.aspectRatio;
      elements.image.src = this.objectUrl;

      elements.image.$ready().then(function(source) {
        if (this.settled) return;

        this.matchCanvasToImage(elements.canvas, source);
        elements.image.$center("contain");
        this.selectWholeImage(elements);
        this.bindCropperHandlers(elements);
      }.bind(this)).catch(function() {
        this.dismiss();
      }.bind(this));
    },

    // Without this the canvas keeps its declared ratio and `contain` letterboxes
    // the image, which the shade then paints as grey bars along two edges.
    matchCanvasToImage: function(canvas, source) {
      canvas.style.setProperty(
        "--image-cropper-canvas-ratio",
        source.naturalWidth / source.naturalHeight
      );
    },

    bindCropperHandlers: function(elements) {
      elements.selection.addEventListener("change", this.boundSelectionChange);
      elements.image.addEventListener("transform", this.boundImageTransform);
    },

    unbindCropperHandlers: function() {
      const elements = this.getCropperElements();

      elements.selection.removeEventListener("change", this.boundSelectionChange);
      elements.image.removeEventListener("transform", this.boundImageTransform);
    },

    // Replaces v1's `viewMode: 1`: v2 lets the selection roam the whole canvas,
    // so a crop dragged past the image would bake transparent padding into the
    // output file. A 1px tolerance absorbs the rounding $change applies.
    handleSelectionChange: function(event) {
      const bounds = this.imageBounds();
      const detail = event.detail;

      if (!bounds) return;

      if (detail.x < bounds.left - 1 ||
          detail.y < bounds.top - 1 ||
          detail.x + detail.width > bounds.left + bounds.width + 1 ||
          detail.y + detail.height > bounds.top + bounds.height + 1) {
        event.preventDefault();
      }
    },

    // Panning or zooming moves the image out from under the selection, which
    // the change guard above cannot see. Re-fit once the new transform has
    // been applied.
    handleImageTransform: function() {
      window.requestAnimationFrame(function() {
        if (this.settled) return;

        this.shrinkSelectionIntoImage(this.getCropperElements());
      }.bind(this));
    },

    selectWholeImage: function(elements) {
      const bounds = this.imageBounds();

      if (!bounds) return;

      const size = this.fitToAspectRatio(bounds.width, bounds.height);
      const x = bounds.left + ((bounds.width - size.width) / 2);
      const y = bounds.top + ((bounds.height - size.height) / 2);

      elements.selection.$change(x, y, size.width, size.height);
    },

    shrinkSelectionIntoImage: function(elements) {
      const bounds = this.imageBounds();
      const selection = elements.selection;

      if (!bounds) return;

      const size = this.fitToAspectRatio(
        Math.min(selection.width, bounds.width),
        Math.min(selection.height, bounds.height)
      );
      const x = this.clamp(selection.x, bounds.left, bounds.left + bounds.width - size.width);
      const y = this.clamp(selection.y, bounds.top, bounds.top + bounds.height - size.height);

      selection.$change(x, y, size.width, size.height);
    },

    fitToAspectRatio: function(width, height) {
      if (!this.aspectRatio || !isFinite(this.aspectRatio)) return { width: width, height: height };

      if (height * this.aspectRatio > width) return { width: width, height: width / this.aspectRatio };

      return { width: height * this.aspectRatio, height: height };
    },

    // The image rect in canvas coordinates — the coordinate space the
    // selection's x/y/width/height live in.
    imageBounds: function() {
      const elements = this.getCropperElements();
      const canvasRect = elements.canvas.getBoundingClientRect();
      const imageRect = elements.image.getBoundingClientRect();

      if (!imageRect.width || !imageRect.height) return null;

      return {
        left: imageRect.left - canvasRect.left,
        top: imageRect.top - canvasRect.top,
        width: imageRect.width,
        height: imageRect.height
      };
    },

    handleConfirm: function() {
      if (this.settled) return;

      const selection = this.getCropperElements().selection;

      if (!selection.width || !selection.height) return;

      selection.$toCanvas(this.canvasOptions(selection))
        .then(function(canvas) {
          canvas.toBlob(this.handleCroppedBlob.bind(this), this.outputType(), this.JPEG_QUALITY);
        }.bind(this))
        .catch(function() {
          this.dismiss();
        }.bind(this));
    },

    // Fires onConfirm directly from the confirm-button chain — NOT via the
    // dialog "close" event, which can be unreliable (e.g. a Turbolinks-cached
    // modal). settle() then closes the dialog and drops the callbacks.
    handleCroppedBlob: function(blob) {
      if (this.settled) return;

      const onConfirm = this.onConfirm;
      const file = new File([blob], this.fileName, { type: this.outputType() });

      this.settle();

      if (onConfirm) onConfirm(file);
    },

    handleCancel: function() {
      this.dismiss();
    },

    // Esc / close-button dismissal arrives here through the dialog "close"
    // event. Confirm and Cancel settle first, so this only acts on a real
    // dismissal.
    handleModalClose: function() {
      this.dismiss();
    },

    dismiss: function() {
      if (this.settled) return;

      const onCancel = this.onCancel;

      this.settle();

      if (onCancel) onCancel();
    },

    settle: function() {
      this.settled = true;

      this.teardownCropper();
      this.revokeObjectUrl();
      this.closeModal();

      this.onConfirm = null;
      this.onCancel = null;
    },

    closeModal: function() {
      const modal = this.getModal();
      if (!modal.open) return;

      App.SharedModal.closeById(this.MODAL_ID);
    },

    // Stored bound reference + remove/add keeps this idempotent and, unlike a
    // data-attribute guard, survives Turbolinks page caching: a cached modal
    // carries no JS listener, so it must be rebound on every open.
    bindModalCloseHandler: function() {
      const modal = this.getModal();

      modal.removeEventListener("close", this.boundModalClose);
      modal.addEventListener("close", this.boundModalClose);
    },

    // $toCanvas sizes the output from the selection's on-screen size, so the
    // displayed scale has to be divided out to get back to source pixels.
    // Only the cap is passed on, since $toCanvas has no max-size mode and
    // would otherwise upscale a small crop.
    canvasOptions: function(selection) {
      const transform = this.getCropperElements().image.$getTransform();
      const scale = Math.sqrt((transform[0] * transform[0]) + (transform[1] * transform[1])) || 1;
      const sourceWidth = selection.width / scale;
      const sourceHeight = selection.height / scale;
      const cap = Math.min(1, this.OUTPUT_MAX_DIMENSION / Math.max(sourceWidth, sourceHeight));

      return {
        width: sourceWidth * cap,
        beforeDraw: function(context) {
          context.imageSmoothingQuality = "high";
        }
      };
    },

    outputType: function() {
      if (this.fileType === "image/jpeg") return "image/jpeg";
      if (this.fileType === "image/webp") return "image/webp";

      return "image/png";
    },

    teardownCropper: function() {
      const elements = this.getCropperElements();

      this.unbindCropperHandlers();
      elements.selection.$clear();
      elements.image.removeAttribute("src");
      elements.canvas.style.removeProperty("--image-cropper-canvas-ratio");
    },

    revokeObjectUrl: function() {
      if (!this.objectUrl) return;

      URL.revokeObjectURL(this.objectUrl);
      this.objectUrl = null;
    },

    reset: function() {
      this.onConfirm = null;
      this.onCancel = null;
      this.aspectRatio = NaN;
      this.fileName = null;
      this.fileType = null;
      this.settled = false;
    },

    clamp: function(value, min, max) {
      return Math.min(Math.max(value, min), Math.max(min, max));
    },

    isCroppableImage: function(file) {
      return /^image\/(jpeg|png|webp)$/.test(file.type);
    },

    getModal: function() {
      return document.getElementById(this.MODAL_ID);
    },

    getCropperElements: function() {
      const modal = this.getModal();

      return {
        canvas: modal.querySelector("cropper-canvas"),
        image: modal.querySelector("cropper-image"),
        selection: modal.querySelector("cropper-selection")
      };
    }
  };
}).call(this);
