(function() {
  "use strict";

  App.ImageCropper = {
    MODAL_ID: "image-cropper-modal",
    OUTPUT_MAX_DIMENSION: 2400,
    JPEG_QUALITY: 0.92,

    initialize: function() {
      this.boundModalClose = this.handleModalClose.bind(this);
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
      const image = this.getImageElement();

      this.revokeObjectUrl();
      this.objectUrl = URL.createObjectURL(file);
      image.src = this.objectUrl;

      this.bindModalCloseHandler();
      App.SharedModal.open(this.MODAL_ID);
      this.initCropper(image);
    },

    // Cropper.js must initialize after the dialog is visible, otherwise it
    // measures a zero-sized container and the crop box never appears.
    initCropper: function(image) {
      this.destroyCropper();
      this.cropper = new Cropper(image, {
        aspectRatio: this.aspectRatio,
        viewMode: 1,
        autoCropArea: 1,
        background: false,
        responsive: true
      });
    },

    handleConfirm: function() {
      if (this.settled) return;
      if (!this.cropper) return;

      const canvas = this.cropper.getCroppedCanvas(this.canvasOptions());
      canvas.toBlob(this.handleCroppedBlob.bind(this), this.outputType(), this.JPEG_QUALITY);
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

      this.destroyCropper();
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

    canvasOptions: function() {
      return {
        maxWidth: this.OUTPUT_MAX_DIMENSION,
        maxHeight: this.OUTPUT_MAX_DIMENSION,
        imageSmoothingQuality: "high"
      };
    },

    outputType: function() {
      if (this.fileType === "image/jpeg") return "image/jpeg";
      if (this.fileType === "image/webp") return "image/webp";

      return "image/png";
    },

    destroyCropper: function() {
      if (!this.cropper) return;

      this.cropper.destroy();
      this.cropper = null;
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

    isCroppableImage: function(file) {
      return /^image\/(jpeg|png|webp)$/.test(file.type);
    },

    getModal: function() {
      return document.getElementById(this.MODAL_ID);
    },

    getImageElement: function() {
      return this.getModal().querySelector(".js-image-cropper--image");
    }
  };
}).call(this);
