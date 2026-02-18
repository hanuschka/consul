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

      $form.on("submit", () => this.showLoader());
    },

    initStep2ImageGeneration() {
      const $body = $(".js-ai-flow-step2-body");

      if (!$body.length) return;

      const dataset = $body.get(0).dataset;

      if (!dataset.imagePrompt) return;
      if (dataset.hasImage === "true") return;

      if (!App.AssistantUserResourceForm.element) {
        App.AssistantUserResourceForm.initialize($body.get(0));
      }

      App.AssistantUserResourceForm.generateImage(dataset.imagePrompt);
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
