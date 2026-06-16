(function() {
  "use strict";
  App.ImageUploadComponent = {
    initialize: function() {
      App.ImageUploadComponent.initEvents();
    },

    initEvents: function() {
      $(".js-dropzone-image-upload-custom-edit-button").each(function(_index, fileAttachArea) {
        fileAttachArea.addEventListener("click", App.ImageUploadComponent.fileAttachAreaClick);
      });

      $(".js-dropzone-image-upload--input").each(function(_index, fileAttachArea) {
        fileAttachArea.addEventListener("change", App.ImageUploadComponent.handleFileChange);
      });
    },

    fileAttachAreaClick: function(e) {
      var uploadInput =
        e.currentTarget
          .closest(".js-dropzone-image-upload")
          .querySelector(".js-dropzone-image-upload--input")
          .click();
    },

    handleFileChange: function(e) {
      var input = e.currentTarget;
      var file = input.files[0];

      if (!file) return;

      var wrapper = input.closest(".js-dropzone-image-upload");

      if (!App.ImageUploadComponent.validateSize(file, input)) return;

      if (App.ImageUploadComponent.shouldCrop(wrapper, file)) {
        App.ImageUploadComponent.openCropper(wrapper, input, file);
        return;
      }

      App.ImageUploadComponent.applyFileAndSubmit(input, wrapper);
    },

    validateSize: function(file, input) {
      var fileSizeMb = (file.size / 1024 / 1024).toFixed(2);

      if (fileSizeMb > 5) {
        alert("File size must be less than 5 MB.");
        input.value = "";
        return false;
      }

      return true;
    },

    shouldCrop: function(wrapper, file) {
      if (wrapper.dataset.crop !== "true") return false;

      return App.ImageCropper.isCroppableImage(file);
    },

    openCropper: function(wrapper, input, file) {
      App.ImageCropper.open(file, {
        aspectRatio: parseFloat(wrapper.dataset.cropAspectRatio),
        onConfirm: function(croppedFile) {
          App.ImageUploadComponent.setInputFile(input, croppedFile);
          App.ImageUploadComponent.applyFileAndSubmit(input, wrapper);
        },
        onCancel: function() {
          input.value = "";
        }
      });
    },

    setInputFile: function(input, file) {
      var dataTransfer = new DataTransfer();
      dataTransfer.items.add(file);
      input.files = dataTransfer.files;
    },

    applyFileAndSubmit: function(input, wrapper) {
      var file = input.files[0];
      var preview = wrapper.querySelector(".js-dropzone-image-upload--preview");
      var previewWrapper = wrapper.querySelector(".js-dropzone-image-upload--preview-wrapper");
      var fileReader = new FileReader();

      fileReader.onload = function(event) {
        preview.setAttribute("src", event.target.result);
        previewWrapper.classList.add("-visible");
      };

      fileReader.readAsDataURL(file);

      if (wrapper.dataset.submitForm) {
        App.ImageUploadComponent.submitFormViaAjax(wrapper.closest("form"), input);
      }
    },

    // jquery-ujs serializeArray() drops file inputs, so the remote form falls
    // back to a full multipart submit + redirect (a page navigation). Submit
    // the file explicitly via FormData so the request stays AJAX and the
    // controller answers with format.js (update.js.erb) — no page reload.
    submitFormViaAjax: function(form, input) {
      var formData = new FormData(form);

      input.disabled = true;

      App.Ajax
        .request({
          method: "POST",
          url: form.getAttribute("action"),
          data: formData,
          processData: false,
          contentType: false,
          dataType: "script"
        })
        .fail(function() {
          input.disabled = false;
        });
    },
  };
}).call(this);
