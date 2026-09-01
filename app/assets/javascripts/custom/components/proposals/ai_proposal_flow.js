(function() {
  "use strict";

  App.AiProposalFlow = {
    initialize() {
      this.initCharCounter();
      this.initStep1SubmitLoader();
      this.initStep2ImageGeneration();
      this.initStep2SubmitLoader();
      this.initStep2RemoveImage();
    },

    initCharCounter() {
      const $textarea = $(".js-ai-flow-idea-textarea");
      const $counter = $(".js-ai-flow-char-count");

      if (!$textarea.length) return;

      $counter.text($textarea.val().length);

      $textarea.on("input", function() { $counter.text(this.value.length); });
    },

    initStep1SubmitLoader() {
      const $form = $(".js-ai-flow-step1-form");

      if (!$form.length) return;

      $form.on("submit", (e) => {
        const value = $(".js-ai-flow-idea-textarea").val().trim();

        if (!value) {
          e.preventDefault();
          return;
        }

        this.showLoader();
      });
    },

    initStep2ImageGeneration() {
      const $body = $(".js-ai-flow-step2-body");

      if (!$body.length) return;

      const dataset = $body.get(0).dataset;

      if (!dataset.imagePrompt) return;
      if (dataset.hasImage === "true") return;

      this.generateAndAssignImage(dataset);
    },

    IMAGE_GENERATION_MAX_WAIT_MS: 25000,

    generateAndAssignImage(dataset) {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(true);
      this.setSubmitButtonDisabled(true);

      const safetyTimer = setTimeout(() => {
        this.setSubmitButtonDisabled(false);
      }, this.IMAGE_GENERATION_MAX_WAIT_MS);

      setTimeout(() => {
        App.Ajax
          .post(dataset.generateImageUrl, {
            prompt: dataset.imagePrompt,
            aspect_ratio: dataset.aspectRatio,
            codename: dataset.codename,
            consul_projekt_phase_id: dataset.projektPhaseId,
            resource_type: dataset.resourceType,
            resource_id: dataset.resourceId
          })
          .then(
            (responseData) => {
              clearTimeout(safetyTimer);

              const $upload = $(".js-direct-image-upload:visible").first();

              $upload.find(".js-direct-image-upload-image-preview").attr("src", responseData.image_url);
              $upload.find(".js-direct-image-upload--preview-area").addClass("-preview-set");

              App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(false);
              this.setSubmitButtonDisabled(false);
            },
            (request) => {
              clearTimeout(safetyTimer);
              App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(false);
              this.setSubmitButtonDisabled(false);
              this.showImageError(request.responseJSON && request.responseJSON.error);
            }
          );
      }, 100);
    },

    // The generated image is optional to the draft, so a failure is reported in
    // place of the picture rather than blocking the form.
    showImageError(message) {
      if (!message) return;

      const $upload = $(".js-direct-image-upload:visible").first();

      if ($upload.length === 0) return;

      let $error = $upload.find(".js-ai-image-error");

      if ($error.length === 0) {
        $error = $("<div class='callout alert js-ai-image-error'></div>");
        $upload.prepend($error);
      }

      $error.text(message);
    },

    setSubmitButtonDisabled(disabled) {
      $(".js-ai-flow-step2-submit").prop("disabled", disabled);
    },

    initStep2RemoveImage() {
      const $body = $(".js-ai-flow-step2-body");

      if (!$body.length) return;

      const dataset = $body.get(0).dataset;

      if (!dataset.removeImageUrl) return;

      $body.on("click", ".action-remove a.delete", () => {
        App.Ajax.delete(dataset.removeImageUrl, {
          resource_type: dataset.resourceType,
          resource_id: dataset.resourceId
        });

        $body.find(".js-direct-image-upload--id").val("");
        $body.find(".js-direct-image-upload--cached-attachment").val("");
      });
    },

    initStep2SubmitLoader() {
      const $form = $(".js-ai-flow-step2-form");

      if (!$form.length) return;

      $form.on("submit", () => this.showLoader());
    },

    showLoader() {
      const $body = $(".js-ai-flow-body");

      $body.addClass("-loading");
      $(".js-ai-proposal-loader").removeAttr("hidden");
      this.scrollStepToMiddle($body.get(0));
    },

    scrollStepToMiddle(stepElement) {
      if (!stepElement) return;

      stepElement.scrollIntoView({ behavior: "smooth", block: "center" });
    }
  };
}).call(this);
