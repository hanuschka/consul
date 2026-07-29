(function() {
  "use strict";
  App.DirectUploadComponent = {
    initialize: function() {
      $(".js-direct-image-upload").each(function(_, component) {
        App.DirectUploadComponent.initForOneComponent(component);
      });

      App.DirectUploadComponent.initEvents();
    },

    initEvents: function() {
      $(".js-direct-image-upload--file-attach-area").each(function(_index, fileAttachArea) {
        fileAttachArea.addEventListener("click", App.DirectUploadComponent.fileAttachAreaClick);
      });
      $(".js-direct-image-upload-custom-edit-button").each(function(_index, fileAttachArea) {
        fileAttachArea.addEventListener("click", App.DirectUploadComponent.fileAttachAreaClick);
      });

      $(".js-direct-image-upload-image-preview").each(function(_index, imagePreview) {
        imagePreview.addEventListener("load", App.DirectUploadComponent.handleImagePreviewLoded)
      })

      $(".js-direct-image-upload--confirm-button").each(function(_index, button) {
        button.addEventListener("click", App.DirectUploadComponent.confirmationConfirmClick);
      });

      $(".js-direct-image-upload--cancel-confirmation").each(function(_index, link) {
        link.addEventListener("click", App.DirectUploadComponent.confirmationCancelClick);
      });

      App.DirectUploadComponent.initializeRemoveCachedImageLinks();
    },

    fileAttachAreaClick: function(e) {
      var wrapper = e.currentTarget.closest(".js-direct-image-upload");
      var confirmationStep = wrapper.querySelector(".js-direct-image-upload--confirmation-step");

      if (confirmationStep) {
        wrapper.classList.add("-confirmation-pending");
        return;
      }

      wrapper.querySelector(".js-direct-image-upload--input").click();
    },

    confirmationConfirmClick: function(e) {
      e.preventDefault();
      var wrapper = e.currentTarget.closest(".js-direct-image-upload");
      wrapper.querySelector(".js-direct-image-upload--input").click();
    },

    confirmationCancelClick: function(e) {
      e.preventDefault();
      var wrapper = e.currentTarget.closest(".js-direct-image-upload");
      wrapper.classList.remove("-confirmation-pending");
    },

    initForOneComponent: function(component) {
      var input = component.querySelector(".js-direct-image-upload--input");
      var inputData = this.buildData([], input);

      $(input).fileupload({
        paramName: "attachment",
        formData: null,
        add: function(e, data) {
          var target = e.target;
          var wrapper = $(target).closest(".js-direct-image-upload")[0];

          wrapper.classList.remove("-confirmation-pending");

          if (App.DirectUploadComponent.shouldCrop(wrapper, data.files[0])) {
            App.DirectUploadComponent.openCropper(wrapper, target, data);
            return;
          }

          App.DirectUploadComponent.startUpload(target, data);
        },

        change: function(e, data) {
          data.files.forEach(function(file) {
            App.DirectUploadComponent.setFilename(inputData, file.name);
          });
        },

        fail: function(e, data) {
          $(data.cachedAttachmentField).val("");

          App.DirectUploadComponent.clearFilename(data);
          App.DirectUploadComponent.setProgressBar(data, "errors");
          App.DirectUploadComponent.clearInputErrors(data);
          App.DirectUploadComponent.setInputErrors(data);
          App.DirectUploadComponent.clearPreview(data);

          $(data.destroyAttachmentLinkContainer).find("a.delete:not(.remove-nested)").remove();
          $(data.addAttachmentLabel).addClass("error");
        },
        done: function(e, data) {
          console.log("done", data)
          var $dataWrapper = data.wrapper;
          var shouldSubmitForm = $dataWrapper.data("submit-form") === true;

          if (shouldSubmitForm) {
            var $idElemnt = $(".js-direct-image-upload--id");

            $idElemnt.val("");
            $(data.cachedAttachmentField).val("");
          }

          $(data.cachedAttachmentField).val(data.result.cached_attachment);

          App.DirectUploadComponent.setTitleFromFile(data, data.result.filename);
          App.DirectUploadComponent.clearProgressBar(data);
          App.DirectUploadComponent.setFilename(data, data.result.filename);
          App.DirectUploadComponent.clearInputErrors(data);
          App.DirectUploadComponent.setPreview(data);
          var destroyAttachmentLink = $(data.result.destroy_link);
          $(data.destroyAttachmentLinkContainer).html(destroyAttachmentLink);

          if (shouldSubmitForm) {
            var form = $dataWrapper.closest("form")[0];
            form.requestSubmit();
          }
        },

        progress: function(e, data) {
          var progress;
          progress = parseInt(data.loaded / data.total * 100, 10);
          $(data.progressBar).find(".direct-image-upload--loading-bar").css("width", progress + "%");
        }
      });
    },

    shouldCrop: function(wrapper, file) {
      if (!wrapper) return false;
      if (wrapper.dataset.crop !== "true") return false;

      return App.ImageCropper.isCroppableImage(file);
    },

    openCropper: function(wrapper, target, data) {
      App.ImageCropper.open(data.files[0], {
        aspectRatio: parseFloat(wrapper.dataset.cropAspectRatio),
        onConfirm: function(croppedFile) {
          data.files = [croppedFile];
          App.DirectUploadComponent.startUpload(target, data);
        },
        onCancel: function() {
          target.value = "";
        }
      });
    },

    startUpload: function(target, data) {
      var upload_data = App.DirectUploadComponent.buildData(data, target);

      App.DirectUploadComponent.clearProgressBar(upload_data);
      App.DirectUploadComponent.setProgressBar(upload_data, "uploading");

      upload_data.submit();
    },

    buildData: function(data, input) {
      var wrapper;
      wrapper = $(input).closest(".js-direct-image-upload");
      var $wrapper = $(wrapper);

      data.wrapper = wrapper;
      data.progressBar = $wrapper.find(".direct-image-upload--progress-bar-wrapper");
      data.preview = $wrapper.find(".image-preview");
      data.imagePreview = $wrapper.find(".js-direct-image-upload-image-preview");
      data.previewArea = $wrapper.find(".js-direct-image-upload--preview-area");
      data.errorContainer = $wrapper.find(".js-attachment-errors");
      data.fileNameContainer = $wrapper.find(".js-file-name");
      data.destroyAttachmentLinkContainer = $wrapper.find(".action-remove");
      data.addAttachmentLabel = $wrapper.find(".action-add label");
      data.cachedAttachmentField = $wrapper.find("input[name$='[cached_attachment]']");
      data.titleField = $wrapper.find("input[name$='[title]']");
      $wrapper.find(".direct-image-upload--progress-bar-wrapper").css("display", "block");

      return data;
    },

    handleImagePreviewLoded: function(e) {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(false)
    },

    clearFilename: function(data) {
      $(data.fileNameContainer).text("");
      $(data.fileNameContainer).attr("title", "");
    },
    clearInputErrors: function(data) {
      $(data.errorContainer).find("small.error").remove();
    },

    clearProgressBar: function(data) {
      $(data.progressBar).find(".direct-image-upload--loading-bar").removeClass("complete errors uploading").css("width", "0px");
      data.progressBar.css("display", "none");
    },

    clearPreview: function(data) {
      $(data.wrapper).find(".image-preview").remove();
    },

    setFilename: function(data, file_name) {
      $(data.fileNameContainer).text(file_name);
      $(data.fileNameContainer).attr("title", file_name);
    },

    setProgressBar: function(data, klass) {
      data.progressBar.css("display", "block");
      $(data.progressBar).find(".direct-image-upload--loading-bar").addClass(klass);
    },

    setTitleFromFile: function(data, title) {
      if ($(data.titleField).val() === "") {
        $(data.titleField).val(title);
      }
    },

    setInputErrors: function(data) {
      var errors = "<small class='error'>" + data.jqXHR.responseJSON.errors + "</small>";
      $(data.errorContainer).append(errors);
    },

    setPreview: function(data) {
      data.imagePreview.attr("src", data.result.attachment_url);
      data.previewArea.addClass("-preview-set");
    },

    toggleGeneratingPlaceholderAnimation: function(visible) {
      $(".js-direct-image-upload")
        .toggleClass("-generating-image", visible)
    },

    initializeRemoveCachedImageLinks: function() {
      $(".js-direct-image-upload").on("click", ".remove-cached-attachment", function(event) {
        event.preventDefault();
        // $("#new_image_link").removeClass("hide");
        var $mainElement = $(this).closest(".js-direct-image-upload");

        $mainElement.find(".js-direct-image-upload--preview-area").removeClass("-preview-set");
        $mainElement.find(".js-direct-image-upload--cached-attachment").val("");
      });
    },
  };
}).call(this);
