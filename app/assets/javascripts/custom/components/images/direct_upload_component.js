(function() {
  "use strict";
  App.DirectUploadComponent = {
    initialize: function() {
      $(".js-direct-image-upload--input").each(function(index, directUploadInput) {
        App.DirectUploadComponent.initializeDirectUploadInput(directUploadInput);
      });

      $(".js-direct-image-upload--file-attach-area").each(function(index, fileAttachArea) {
        fileAttachArea.addEventListener("click", App.DirectUploadComponent.fileAttachAreaClick);
      });
      App.DirectUploadComponent.initializeRemoveCachedImageLinks();
    },

    fileAttachAreaClick: function(e) {
      e.currentTarget.querySelector('.js-direct-image-upload--input').click();
    },

    initializeDirectUploadInput: function(input) {
      var inputData;
      inputData = this.buildData([], input);

      $(input).fileupload({
        paramName: "attachment",
        formData: null,
        add: function(e, data) {
          console.log("DirectUploadComponent.add")
          var upload_data;
          upload_data = App.DirectUploadComponent.buildData(data, e.target);
          App.DirectUploadComponent.clearProgressBar(upload_data);
          App.DirectUploadComponent.setProgressBar(upload_data, "uploading");
          upload_data.submit();
        },
        change: function(e, data) {
          console.log("DirectUploadComponent.change")
          data.files.forEach(function(file) {
            App.DirectUploadComponent.setFilename(inputData, file.name);
          });
        },
        fail: function(e, data) {
          console.log("DirectUploadComponent.fail")
          var upload_data;
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
          console.log("DirectUploadComponent.done")
          console.log(data.cachedAttachmentField)
          var destroyAttachmentLink;
          $(data.cachedAttachmentField).val(data.result.cached_attachment);
          App.DirectUploadComponent.setTitleFromFile(data, data.result.filename);
          App.DirectUploadComponent.setProgressBar(data, "complete");
          App.DirectUploadComponent.setFilename(data, data.result.filename);
          App.DirectUploadComponent.clearInputErrors(data);
          App.DirectUploadComponent.setPreview(data);
          destroyAttachmentLink = $(data.result.destroy_link);
          $(data.destroyAttachmentLinkContainer).html(destroyAttachmentLink);
        },
        progress: function(e, data) {
          console.log("DirectUploadComponent.progress")
          var progress;
          progress = parseInt(data.loaded / data.total * 100, 10);
          $(data.progressBar).find(".loading-bar").css("width", progress + "%");
        }
      });
    },
    buildData: function(data, input) {
      var wrapper;
      wrapper = $(input).closest(".js-direct-image-upload");
      var $wrapper = $(wrapper);

      data.wrapper = wrapper;
      data.progressBar = $wrapper.find(".progress-bar-placeholder");
      data.preview = $wrapper.find(".image-preview");
      data.errorContainer = $wrapper.find(".js-attachment-errors");
      data.fileNameContainer = $wrapper.find(".js-file-name");
      data.destroyAttachmentLinkContainer = $wrapper.find(".action-remove");
      data.addAttachmentLabel = $wrapper.find(".action-add label");
      data.cachedAttachmentField = $wrapper.find("input[name$='[cached_attachment]']");
      data.titleField = $wrapper.find("input[name$='[title]']");
      $wrapper.find(".progress-bar-placeholder").css("display", "block");

      return data;
    },
    clearFilename: function(data) {
      $(data.fileNameContainer).text("");
      $(data.fileNameContainer).attr("title", "");
    },
    clearInputErrors: function(data) {
      $(data.errorContainer).find("small.error").remove();
    },
    clearProgressBar: function(data) {
      $(data.progressBar).find(".loading-bar").removeClass("complete errors uploading").css("width", "0px");
    },
    clearPreview: function(data) {
      $(data.wrapper).find(".image-preview").remove();
    },
    setFilename: function(data, file_name) {
      $(data.fileNameContainer).text(file_name);
      $(data.fileNameContainer).attr("title", file_name);
    },
    setProgressBar: function(data, klass) {
      $(data.progressBar).find(".loading-bar").addClass(klass);
    },
    setTitleFromFile: function(data, title) {
      if ($(data.titleField).val() === "") {
        $(data.titleField).val(title);
      }
    },
    setInputErrors: function(data) {
      var errors;
      errors = "<small class='error'>" + data.jqXHR.responseJSON.errors + "</small>";
      $(data.errorContainer).append(errors);
    },
    setPreview: function(data) {
      var image_preview;
      image_preview = "<div class='image-preview'><figure><img src='" + data.result.attachment_url + '?' + Date.now() + "' class='cached-image'></figure></div>";

      if ($(data.preview).length > 0) {
        $(data.preview).replaceWith(image_preview);
      } else {
        var $dataWrapper = $(data.wrapper);
        var $actionsArea = $dataWrapper.find(".js-direct-image-upload--attachment-actions");

        $(image_preview).insertBefore($actionsArea);
        data.preview = $dataWrapper.find(".image-preview");

        $dataWrapper.find(".js-direct-image-upload--preview-area").addClass("-active");
      }
    },

    initializeRemoveCachedImageLinks: function() {
      $(".js-direct-image-upload").on("click", ".remove-cached-attachment", function(event) {
        event.preventDefault();
        // $("#new_image_link").removeClass("hide");
        var $mainElement = $(this).closest(".js-direct-image-upload");

        $mainElement.find(".image-preview").remove();
        $mainElement.find(".js-direct-image-upload--preview-area").removeClass("-active");
      });
    },
  };
}).call(this);
