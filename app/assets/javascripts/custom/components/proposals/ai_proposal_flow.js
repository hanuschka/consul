(function() {
  "use strict";

  App.AiProposalFlow = {
    initialize() {
      this.initCharCounter();
      this.initStep1SubmitLoader();
      this.initStep2ImageGeneration();
      this.initStep2SubmitLoader();
    },

    initCharCounter() {
      const $textarea = $(".js-ai-flow-idea-textarea");
      const $counter = $(".js-ai-flow-char-count");

      if (!$textarea.length) return;

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

    generateAndAssignImage(dataset) {
      App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(true);

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
          .then((responseData) => {
            const $upload = $(".js-direct-image-upload:visible").first();

            $upload.find(".js-direct-image-upload-image-preview").attr("src", responseData.image_url);
            $upload.find(".js-direct-image-upload--preview-area").addClass("-preview-set");

            App.DirectUploadComponent.toggleGeneratingPlaceholderAnimation(false);
          });
      }, 100);
    },

    initStep2SubmitLoader() {
      const $form = $(".js-ai-flow-step2-form");

      if (!$form.length) return;

      $form.on("submit", () => this.showLoader());
    },

    showLoader() {
      $(".js-ai-proposal-loader").removeAttr("hidden");
    }
  };
}).call(this);
