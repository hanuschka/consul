(function() {
  "use strict";

  App.Studio.ContentBlocks.CreateWithAi = {
    state: {
      mode: "add",
      replaceTargetWrapper: null,
      previousContentBlockWrapper: null,
      addAtTop: false,
      targetContentBlockId: null,
      previousContentBlockId: null,
      contentBlockId: null,
      generateUrl: null,
      statusUrl: null,
      cancelUrl: null,
      pollAttempts: 0,
      pollActive: false,
      categoriesAvailable: false,
      categories: []
    },

    initialize() {
      const $document = $(document);

      $document.on("click", ".js-open-create-content-block-with-ai", this.handleOpen.bind(this));
      $document.on("click", ".js-content-block-ai-submit", this.handleSubmit.bind(this));
      $document.on("click", ".js-content-block-ai-cancel", this.handleCancel.bind(this));
      $document.on("click", ".js-content-block-ai-modal-close", this.handleCloseRequest.bind(this));
      $document.on("keydown", ".js-content-block-ai-modal", this.handleSubmitShortcut.bind(this));

      this.applyShortcutLabel();
      this.bindUnloadCancel();
    },

    isMacPlatform() {
      const platform =
        (navigator.userAgentData && navigator.userAgentData.platform) ||
        navigator.platform ||
        navigator.userAgent;

      return /Mac|iPhone|iPad|iPod/i.test(platform);
    },

    applyShortcutLabel() {
      const label = this.isMacPlatform() ? "⌘ + Enter" : "Ctrl + Enter";
      $(".js-content-block-ai-shortcut").text(label);
    },

    handleSubmitShortcut(e) {
      if (e.key !== "Enter") return
      if (!(e.metaKey || e.ctrlKey)) return

      const modal = document.querySelector(".js-content-block-ai-modal");
      if (modal.dataset.state !== "idle") return

      this.handleSubmit(e);
    },

    bindUnloadCancel() {
      window.addEventListener("beforeunload", () => {
        if (!this.state.pollActive) return
        if (!this.state.cancelUrl) return

        navigator.sendBeacon && navigator.sendBeacon(this.state.cancelUrl, "");
      });
    },

    handleOpen(e) {
      e.preventDefault();

      if (App.Studio.Projekt.isAiTriggerDisabled(e.currentTarget)) return

      const directSection = e.currentTarget.closest(".js-show-content-block-templates-section");
      if (directSection) {
        const wrapper = App.Studio.ContentBlocks.DomHelpers.getParentContentBlockWrapper(e.currentTarget);
        const isAtTop = directSection.classList.contains("js-add-content-block-at-top");

        App.Studio.ContentBlocks.TemplateSelector.selectionMode = "add";
        App.Studio.ContentBlocks.TemplateSelector.replaceTargetWrapper = null;
        App.Studio.ContentBlocks.TemplateSelector.currentContentBlockId = wrapper ? wrapper.dataset.contentBlockId : null;
        App.Studio.ContentBlocks.Crud.addContentBlockAfter = wrapper;
        App.Studio.ContentBlocks.Crud.addContentBlockAtTop = isAtTop;
      }

      const templateSelector = App.Studio.ContentBlocks.TemplateSelector;
      const crud = App.Studio.ContentBlocks.Crud;

      this.state.mode = templateSelector.selectionMode === "replace" ? "replace" : "add";
      this.state.replaceTargetWrapper = templateSelector.replaceTargetWrapper;
      this.state.previousContentBlockWrapper = crud.addContentBlockAfter;
      this.state.addAtTop = crud.addContentBlockAtTop;
      this.state.targetContentBlockId = templateSelector.replaceTargetWrapper
        ? templateSelector.replaceTargetWrapper.dataset.contentBlockId
        : null;
      this.state.previousContentBlockId = crud.addContentBlockAfter
        ? crud.addContentBlockAfter.dataset.contentBlockId
        : null;
      this.state.generateUrl = this.state.replaceTargetWrapper
        ? this.state.replaceTargetWrapper.dataset.generateUrl
        : null;

      templateSelector.closeDialog();

      this.resetUI();
      this.openModal();
      this.loadMetadata();
    },

    openModal() {
      App.SharedModal.open("contentBlockAiModal");
      setTimeout(() => {
        $(".js-content-block-ai-prompt").trigger("focus");
      }, 200);
    },

    closeModal() {
      const modal = document.getElementById("contentBlockAiModal");

      if (modal.open) {
        App.SharedModal.closeById("contentBlockAiModal");
      }
    },

    resetUI() {
      const modal = document.querySelector(".js-content-block-ai-modal");
      modal.dataset.state = "idle";

      $(".js-content-block-ai-prompt").val("");
      $(".js-content-block-ai-context").prop("checked", false);
      $(".js-content-block-ai-context-row").toggleClass("hide", !!this.state.generateUrl);
      $(".js-content-block-ai-loader").hide();
      $(".js-content-block-ai-error").hide().text("");
      $(".js-content-block-ai-fallback-note").hide();
      $(".js-content-block-ai-modal-close").show();
      $(".js-content-block-ai-submit").prop("disabled", false);
      $(".js-content-block-ai-category").val("");
    },

    getContentBlocksList() {
      return document.querySelector(".js-content-blocks-list");
    },

    getTemplateSection() {
      const contentBlocksList = this.getContentBlocksList();

      if (contentBlocksList && contentBlocksList.dataset.templateSection) {
        return contentBlocksList.dataset.templateSection;
      }

      return null;
    },

    getGenerateUrl() {
      if (this.state.generateUrl) return this.state.generateUrl

      return App.Studio.Projekt.config.generateUrl;
    },

    loadMetadata() {
      const metadataData = {};
      const templateSection = this.getTemplateSection();

      if (templateSection) {
        metadataData.section = templateSection;
      }

      App.Ajax
        .request({
          url: "/projekt_content_block_templates/metadata",
          method: "GET",
          dataType: "json",
          data: metadataData
        })
        .then((data) => this.populateCategories(data))
        .catch(() => this.populateCategories({ available: false, categories: [] }));
    },

    populateCategories(data) {
      this.state.categoriesAvailable = !!data.available;
      this.state.categories = data.categories || [];

      const $categorySelect = $(".js-content-block-ai-category");
      const anyOption = $categorySelect.find("option").first().clone();

      $categorySelect.empty().append(anyOption);

      this.state.categories.forEach((category) => {
        $categorySelect.append(
          $("<option>").val(category.id || category.name).text(category.name)
        );
      });

      $(".js-content-block-ai-fallback-note").toggle(!this.state.categoriesAvailable);
    },

    handleSubmit(e) {
      e.preventDefault();

      const prompt = $(".js-content-block-ai-prompt").val().trim();

      if (!prompt) {
        this.showError("Bitte geben Sie einen Prompt ein.");
        return
      }

      this.startGeneration(prompt);
    },

    startGeneration(prompt) {
      const payload = {
        prompt: prompt,
        mode: this.state.mode,
        category_hint: $(".js-content-block-ai-category").val(),
        use_projekt_context: $(".js-content-block-ai-context").is(":checked"),
        previous_content_block_id: this.state.previousContentBlockId,
        add_at_top: this.state.addAtTop,
        target_content_block_id: this.state.targetContentBlockId
      };

      this.enterProcessingMode();

      App.Ajax
        .request({
          url: this.getGenerateUrl(),
          method: "POST",
          dataType: "json",
          data: payload
        })
        .then((data) => this.handleStartResponse(data))
        .catch((response) => this.handleStartError(response));
    },

    handleStartResponse(data) {
      if (data.error) {
        this.showError(data.error.message || "Fehler beim Generieren");
        this.exitProcessingMode();
        return
      }

      this.state.contentBlockId = data.content_block_id;
      this.state.statusUrl = data.status_url;
      this.state.cancelUrl = data.cancel_url;

      this.startPolling();
    },

    handleStartError(response) {
      const message = (response && response.error && response.error.message)
        ? response.error.message
        : "Netzwerkfehler beim Generieren";

      this.showError(message);
      this.exitProcessingMode();
    },

    enterProcessingMode() {
      const modal = document.querySelector(".js-content-block-ai-modal");
      modal.dataset.state = "processing";

      $(".js-content-block-ai-submit").prop("disabled", true);
      $(".js-content-block-ai-loader").show();
      $(".js-content-block-ai-error").hide().text("");
      $(".js-content-block-ai-modal-close").hide();
    },

    exitProcessingMode() {
      const modal = document.querySelector(".js-content-block-ai-modal");
      modal.dataset.state = "idle";

      $(".js-content-block-ai-submit").prop("disabled", false);
      $(".js-content-block-ai-loader").hide();
      $(".js-content-block-ai-modal-close").show();

      this.state.pollActive = false;
    },

    startPolling() {
      this.state.pollActive = true;
      this.state.pollAttempts = 0;
      this.poll();
    },

    poll() {
      if (!this.state.pollActive) return
      if (this.state.pollAttempts >= 300) {
        this.handlePollTimeout();
        return
      }

      this.state.pollAttempts++;

      App.Ajax
        .request({
          url: this.state.statusUrl,
          method: "GET",
          dataType: "json"
        })
        .then((response) => this.handlePollResponse(response))
        .catch(() => this.handlePollError());
    },

    handlePollResponse(response) {
      if (!this.state.pollActive) return

      if (response.status === "completed") {
        this.handleCompletion(response);
      }
      else if (response.status === "failed") {
        this.handlePollFailure(response);
      }
      else if (response.status === "cancelled") {
        this.exitProcessingMode();
        this.closeModal();
      }
      else {
        setTimeout(() => this.poll(), 3000);
      }
    },

    handlePollError() {
      if (this.state.pollActive) {
        setTimeout(() => this.poll(), 3000);
      }
    },

    handlePollTimeout() {
      this.exitProcessingMode();
      this.showError("Zeitüberschreitung beim Generieren. Bitte versuchen Sie es erneut.");
    },

    handlePollFailure(response) {
      const message = (response && response.error && response.error.message)
        ? response.error.message
        : "Fehler beim Generieren des Inhaltsblocks.";

      this.exitProcessingMode();
      this.showError(message);
    },

    handleCompletion(response) {
      this.state.pollActive = false;

      if (this.state.mode === "replace") {
        this.applyReplace(response);
      } else {
        this.applyInsert(response);
      }

      this.exitProcessingMode();
      this.closeModal();
    },

    applyInsert(response) {
      const wrapperHTML = App.Studio.Projekt.templateFunctions.addStudioControlsToContentBlock(
        response.body_html,
        { contentBlockId: response.content_block_id }
      );

      const newWrapper = App.Studio.utils.htmlToDomElement(wrapperHTML).firstChild;
      App.Studio.utils.removeFoundationIds(newWrapper);
      App.Studio.ContentBlocks.Crud.applyUrlsToWrapper(newWrapper, response.urls);
      App.Studio.ContentBlocks.DomHelpers.moveMarginToWrapper(newWrapper);

      const previousWrapper = this.state.previousContentBlockWrapper;

      if (this.state.addAtTop) {
        const topSection = document.querySelector(".js-content-blocks-list .js-add-content-block-at-top");

        if (topSection) {
          topSection.after(newWrapper);
        } else {
          $(".js-content-blocks-list").prepend(newWrapper);
        }
      }
      else if (previousWrapper && document.body.contains(previousWrapper)) {
        previousWrapper.after(newWrapper);
      }
      else {
        $(".js-content-blocks-list").append(newWrapper);
      }

      App.Studio.ContentBlocks.Crud.rerenderContentBlockListControls();
      App.Studio.ContentBlocks.EmptyHintToggle.refreshAll();

      newWrapper.classList.add("-highlight-changed");
      setTimeout(() => {
        newWrapper.classList.remove("-highlight-changed");
      }, 1700);

      setTimeout(() => {
        newWrapper.scrollIntoView({ block: "center" });
        App.Studio.ContentBlocks.DomHelpers.reinitFoundationWidgets($(newWrapper).find(".custom-content-block"));
        App.ImageGallery.initialize();
      }, 0);
    },

    applyReplace(response) {
      const wrapper = this.state.replaceTargetWrapper;
      if (!wrapper) return

      const contentBlock = wrapper.querySelector(".js-content-block");
      if (!contentBlock) return

      const updatedContent = App.Studio.utils.htmlToDomElement(response.body_html);
      App.Studio.utils.removeFoundationIds(updatedContent);

      App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock);
      contentBlock.innerHTML = updatedContent.innerHTML;
      App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock);
      App.Studio.ContentBlocks.SimpleEditMode.switchToSimpleEditMode(wrapper);
    },

    handleCancel(e) {
      e.preventDefault();

      if (!this.state.cancelUrl) return

      App.Ajax
        .request({
          url: this.state.cancelUrl,
          method: "DELETE",
          dataType: "json"
        })
        .catch(() => {});
    },

    handleCloseRequest(e) {
      if (this.state.pollActive) {
        e.preventDefault();
        e.stopPropagation();
        return
      }

      this.closeModal();
    },

    showError(message) {
      $(".js-content-block-ai-error").text(message).show();
    }
  };
}).call(this);
