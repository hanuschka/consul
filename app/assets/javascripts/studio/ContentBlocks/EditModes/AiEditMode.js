App.Studio.ContentBlocks.AiEditMode = {
  initialized: false,
  activeGenerations: {},

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-content-block-enter-simple-edit-mode-from-ai", this.switchToSimpleEditModeFromAi.bind(this));
    $document.on("click", ".js-content-block-ai-edit--submit-prompt", this.submitPrompt.bind(this));
  },

  getTemplate() {
    return document.querySelector('.js-ai-edit-popup-template');
  },

  clonePopupFromTemplate() {
    const template = this.getTemplate();
    return template.content.cloneNode(true).querySelector('.js-content-block-ai-edit-popup');
  },

  enterAiEditMode(e) {
    const { contentBlockWrapper, contentBlock } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);

    App.Studio.ContentBlocks.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);

    this.switchToAiEditMode(contentBlockWrapper);
  },

  switchToAiEditMode(contentBlockWrapper) {
    contentBlockWrapper.dataset.editMode = 'ai';
    this.showAiEditModeControls(contentBlockWrapper);
    this.createAndShowPopup(contentBlockWrapper);
  },

  switchToSimpleEditModeFromAi(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);

    this.exitAiEditMode(contentBlockWrapper, false);

    App.Studio.ContentBlocks.SimpleEditMode.switchToSimpleEditMode(contentBlockWrapper);
  },

  getPopup(contentBlockWrapper) {
    const innerContainer = contentBlockWrapper.querySelector('.custom-content-block-wrapper--inner');
    const searchContainer = innerContainer || contentBlockWrapper;
    return searchContainer.querySelector('.js-content-block-ai-edit-popup');
  },

  showAiEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.add('-ai-edit-mode', '-in-edit-mode');

    const loader = contentBlockWrapper.querySelector('.ai-edit-mode--loader');
    if (loader) {
      loader.style.display = 'none';
    }
  },

  hideAiEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.remove('-ai-edit-mode', '-in-edit-mode');
  },

  createAndShowPopup(contentBlockWrapper) {
    this.removePopup(contentBlockWrapper);

    const popup = this.clonePopupFromTemplate();
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    const isSidebar = !!contentBlockWrapper.closest("aside, .sidebar");
    const isFooter = !!contentBlockWrapper.closest("footer");

    if (isSidebar) {
      popup.classList.add("-compact-position");
      contentBlock.after(popup);
    } else if (isFooter) {
      popup.classList.add("-compact-position");
      contentBlock.after(popup);
    } else {
      const toolbarBorder = contentBlockWrapper.querySelector('.js-content-block--toolbar-anchor');
      toolbarBorder.after(popup);
    }

    popup.style.display = 'block';

    const popupLoader = popup.querySelector('.ai-edit-mode--loader');
    if (popupLoader) {
      popupLoader.style.display = 'none';
    }

    const instructionsTextarea = popup.querySelector('.js-ai-instructions-textarea');

    this.setupTextareaListeners(popup, instructionsTextarea);

    setTimeout(() => { instructionsTextarea.focus()}, 100);
  },

  setupTextareaListeners(popup, textarea) {
    const submitButton = popup.querySelector('.js-content-block-ai-edit--submit-prompt');

    textarea.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        if (!submitButton.disabled) {
          submitButton.click();
        }
      }
    });
  },

  removePopup(contentBlockWrapper) {
    const popup = this.getPopup(contentBlockWrapper);
    if (popup) {
      popup.remove();
    }
  },

  exitAiEditMode(contentBlockWrapper, restoreContent = false) {
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    this.cancelGeneration(contentBlockId);

    this.removePopup(contentBlockWrapper);

    if (contentBlockWrapper) {
      this.hideAiEditModeControls(contentBlockWrapper);
      contentBlockWrapper.dataset.editMode = '';

      if (restoreContent) {
        const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
        App.Studio.ContentBlocks.DraftStore.restorePreviousVersion(contentBlock);
      }

      App.Studio.ContentBlocks.DomHelpers.scrollToContentBlockTop(contentBlockWrapper);
    }
  },

  cancelAiEditMode(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    this.exitAiEditMode(contentBlockWrapper, true);
  },

  saveContentBlockAndExit(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const content = contentBlock.innerHTML.trim();

    App.Studio.ContentBlocks.Crud.updateContentBlock(
      contentBlock,
      content
    );

    this.exitAiEditMode(contentBlockWrapper);
  },

  submitPrompt(e) {
    const { contentBlockWrapper } = App.Studio.ContentBlocks.DomHelpers.getContentBlockAndWrapper(e.target);
    const popup = this.getPopup(contentBlockWrapper);
    const submitButton = popup.querySelector('.js-content-block-ai-edit--submit-prompt');
    const instructionsTextarea = popup.querySelector('.js-ai-instructions-textarea');
    const useFullProjektContextCheckbox = popup.querySelector('.js-ai-use-full-projekt-context');
    const allowTextModificationCheckbox = popup.querySelector('.js-ai-allow-text-modification');
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    if (this.activeGenerations[contentBlockId]) {
      this.cancelGeneration(contentBlockId);
      this.finishGeneration(contentBlockId, contentBlockWrapper, popup);
      return;
    }

    const instructions = instructionsTextarea.value.trim();
    const useFullProjektContext = useFullProjektContextCheckbox ? useFullProjektContextCheckbox.checked : false;
    const allowTextModification = allowTextModificationCheckbox ? allowTextModificationCheckbox.checked : false;

    if (!instructionsTextarea.reportValidity()) return

    const contentBlock = App.Studio.ContentBlocks.DomHelpers.getContentBlock(contentBlockWrapper);

    this.setLoadingState(contentBlockWrapper, popup, true);
    this.activeGenerations[contentBlockId] = { poller: null, cancelUrl: null };

    const aiUrl = contentBlockWrapper.dataset.aiUrl
      || `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}/change_with_ai`;

    window.App.Ajax
      .request({
        url: aiUrl,
        type: "PATCH",
        dataType: "json",
        data: {
          instructions: instructions,
          content_block_html: App.Studio.utils.resetMapEmbeds(contentBlock.innerHTML),
          use_full_projekt_context: useFullProjektContext,
          allow_text_modification: allowTextModification
        }
      })
      .then((data) => this.startGenerationPolling(data, contentBlockWrapper, popup, contentBlock))
      .catch((response) => {
        this.handleErrorResponse(response);
        this.finishGeneration(contentBlockId, contentBlockWrapper, popup);
      });

    setTimeout(() => {
      if (this.activeGenerations[contentBlockId]) {
        submitButton.disabled = false;
        this.setButtonState(submitButton, 'cancel');
        instructionsTextarea.disabled = true;
      }
    }, 550);
  },

  // The edit runs as a background job now, so the request only hands back the
  // polling URLs; the generated HTML arrives through the status endpoint.
  startGenerationPolling(data, contentBlockWrapper, popup, contentBlock) {
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const generation = this.activeGenerations[contentBlockId];

    if (!generation) return

    if (data.error) {
      this.showErrorMessage(data.error.message || 'Fehler beim Aktualisieren des Inhaltsblocks');
      this.finishGeneration(contentBlockId, contentBlockWrapper, popup);
      return
    }

    generation.cancelUrl = data.cancel_url;
    generation.poller = App.Studio.ContentBlocks.AiGenerationPoller.start(data.status_url, {
      onProgress: (stepLabel) => this.showStepLabel(popup, stepLabel),
      onCompleted: (response) => {
        this.handleSuccessResponse(response, contentBlock);
        this.finishGeneration(contentBlockId, contentBlockWrapper, popup);
        this.clearInstructions(popup);
      },
      onCancelled: () => this.finishGeneration(contentBlockId, contentBlockWrapper, popup),
      onError: (message) => {
        this.showErrorMessage(message);
        this.finishGeneration(contentBlockId, contentBlockWrapper, popup);
      }
    });
  },

  cancelGeneration(contentBlockId) {
    const generation = this.activeGenerations[contentBlockId];

    if (!generation) return

    if (generation.poller) {
      generation.poller.stop();
    }

    if (generation.cancelUrl) {
      window.App.Ajax
        .request({
          url: generation.cancelUrl,
          method: "DELETE",
          dataType: "json"
        })
        .catch(() => {});
    }

    delete this.activeGenerations[contentBlockId];
  },

  finishGeneration(contentBlockId, contentBlockWrapper, popup) {
    const generation = this.activeGenerations[contentBlockId];

    if (generation && generation.poller) {
      generation.poller.stop();
    }

    delete this.activeGenerations[contentBlockId];

    if (!popup) return

    const submitButton = popup.querySelector('.js-content-block-ai-edit--submit-prompt');
    const instructionsTextarea = popup.querySelector('.js-ai-instructions-textarea');

    submitButton.disabled = false;
    this.setButtonState(submitButton, 'submit');
    instructionsTextarea.disabled = false;

    this.showStepLabel(popup, "");
    this.setLoadingState(contentBlockWrapper, popup, false);
  },

  clearInstructions(popup) {
    popup.querySelector('.js-ai-instructions-textarea').value = "";
  },

  showStepLabel(popup, stepLabel) {
    popup.querySelector('.js-ai-edit-step').textContent = stepLabel;
  },

  handleSuccessResponse(response, contentBlock) {
    if (response.content_block_html) {
      if (contentBlock) {
        contentBlock.innerHTML = App.Studio.utils.sanitizeAdminHtml(response.content_block_html);

        App.Studio.ContentBlocks.DomHelpers.reinitPluginElementsAndWidgets(contentBlock);

        const contentBlockWrapper = contentBlock.closest('.js-content-block-wrapper');
        this.showAiEditSuccessIndicator(contentBlockWrapper);
      }
    } else {
      this.showErrorMessage('Ungültige Antwort vom Server');
    }
  },

  handleErrorResponse(response) {
    let errorMessage = 'Fehler beim Aktualisieren des Inhaltsblocks';

    if (response.responseJSON) {
      if (response.responseJSON.status && response.responseJSON.status.message) {
        errorMessage = response.responseJSON.status.message;
      } else if (response.responseJSON.message) {
        errorMessage = response.responseJSON.message;
      }
    } else if (response.statusText) {
      errorMessage = `${errorMessage}: ${response.statusText}`;
    }

    this.showErrorMessage(errorMessage);
  },

  setLoadingState(contentBlockWrapper, popup, isLoading) {
    if (!contentBlockWrapper || !popup) return;

    const popupSubmitButton = popup.querySelector('.js-content-block-ai-edit--submit-prompt');
    const popupLoader = popup.querySelector('.ai-edit-mode--loader');
    const toolbarSaveButton = contentBlockWrapper.querySelector('.js-save-content-block');
    const instructionsTextarea = popup.querySelector('.js-ai-instructions-textarea');
    const useFullProjektContextCheckbox = popup.querySelector('.js-ai-use-full-projekt-context');
    const allowTextModificationCheckbox = popup.querySelector('.js-ai-allow-text-modification');
    const toolbarLoader = contentBlockWrapper.querySelector('.ai-edit-mode--loader');
    const instructionsHint = popup.querySelector('.js-ai-instructions-hint');

    popupSubmitButton.disabled = isLoading;
    popupSubmitButton.classList.toggle("-green", !isLoading)

    if (!isLoading) {
      this.setButtonState(popupSubmitButton, 'submit');
    }

    popupLoader.style.display = isLoading ? 'block' : 'none';
    toolbarSaveButton.disabled = isLoading;
    instructionsTextarea.disabled = isLoading;

    if (useFullProjektContextCheckbox) {
      useFullProjektContextCheckbox.disabled = isLoading;
    }
    if (allowTextModificationCheckbox) {
      allowTextModificationCheckbox.disabled = isLoading;
    }
    const successIndicator = popup.querySelector('.js-ai-edit-success-indicator');
    const successVisible = successIndicator && successIndicator.style.display !== 'none';
    instructionsHint.style.display = (isLoading || successVisible) ? 'none' : 'block';
    toolbarLoader.style.display = isLoading ? 'block' : 'none';
  },

  showSuccessMessage(message) {
    alert(message);
  },

  showErrorMessage(message) {
    alert(message);
  },

  showAiEditSuccessIndicator(contentBlockWrapper) {
    const popup = this.getPopup(contentBlockWrapper);
    if (!popup) return;

    const successIndicator = popup.querySelector('.js-ai-edit-success-indicator');
    const instructionsHint = popup.querySelector('.js-ai-instructions-hint');
    if (!successIndicator) return;

    successIndicator.style.display = 'inline-flex';
    instructionsHint.style.display = 'none';

    setTimeout(() => {
      successIndicator.style.display = 'none';
      instructionsHint.style.display = 'block';
    }, 3000);
  },

  setButtonState(button, state) {
    const isRunning = state === 'cancel';
    button.classList.toggle('-running', isRunning);
    button.classList.toggle('-green', !isRunning);
  }
};

