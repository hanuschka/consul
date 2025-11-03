ProjektStudio.ContentBlock.AiEditMode = {
  initialized: false,
  templateSelector: '.js-ai-edit-popup-template',
  activeAjaxRequests: {},

  initialize() {
    this.initEventListeners()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-content-block-enter-ai-edit-mode", this.enterAiEditMode.bind(this));

    $document.on("click", ".js-content-block-ai-edit-save", this.saveContentBlockAndExit.bind(this));
    $document.on("click", ".js-content-block-ai-edit-cancel", this.cancelAiEditMode.bind(this));
    $document.on("click", ".js-content-block-enter-simple-edit-mode-from-ai", this.switchToSimpleEditMode.bind(this));

    $document.on("click", ".js-content-block-ai-edit--submit-prompt", this.submitPrompt.bind(this));
  },

  getTemplate() {
    return document.querySelector(this.templateSelector);
  },

  clonePopupFromTemplate() {
    const template = this.getTemplate();
    return template.content.cloneNode(true).querySelector('.js-content-block-ai-edit-popup');
  },

  enterAiEditMode(e) {
    const { contentBlockWrapper, contentBlock } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    ProjektStudio.ContentBlock.DraftStore.storePreviousVersion(contentBlock, contentBlockWrapper);

    this.switchToAiEditMode(contentBlockWrapper);
  },

  switchToAiEditMode(contentBlockWrapper) {
    this.showAiEditModeControls(contentBlockWrapper);
    this.createAndShowPopup(contentBlockWrapper);
  },

  switchToSimpleEditMode(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    this.exitAiEditMode(contentBlockWrapper);

    ProjektStudio.ContentBlock.SimpleEditMode.switchToSimpleEditMode(contentBlockWrapper);
  },

  getPopup(contentBlockWrapper) {
    const relativeContainer = contentBlockWrapper.querySelector('.relative');
    const searchContainer = relativeContainer || contentBlockWrapper;
    return searchContainer.querySelector('.js-content-block-ai-edit-popup');
  },

  showAiEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.add('-ai-edit-mode');

    const loader = contentBlockWrapper.querySelector('.ai-edit-mode--loader');
    if (loader) {
      loader.style.display = 'none';
    }
  },

  hideAiEditModeControls(contentBlockWrapper) {
    contentBlockWrapper.classList.remove('-ai-edit-mode');
  },

  createAndShowPopup(contentBlockWrapper) {
    this.removePopup(contentBlockWrapper);

    const popup = this.clonePopupFromTemplate();
    if (!popup) return;

    const relativeContainer = contentBlockWrapper.querySelector('.relative');
    if (!relativeContainer) return;

    relativeContainer.appendChild(popup);

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

  exitAiEditMode(contentBlockWrapper) {
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    if (this.activeAjaxRequests[contentBlockId]) {
      this.activeAjaxRequests[contentBlockId].abort();
      delete this.activeAjaxRequests[contentBlockId];
    }

    this.removePopup(contentBlockWrapper);

    if (contentBlockWrapper) {
      this.hideAiEditModeControls(contentBlockWrapper);
    }
  },

  cancelAiEditMode(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);

    if (contentBlockWrapper) {
      const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);
      ProjektStudio.ContentBlock.DraftStore.restorePreviousVersion(contentBlock);
    }

    this.exitAiEditMode(contentBlockWrapper);
  },

  saveContentBlockAndExit(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;
    const content = contentBlock.innerHTML.trim();

    ProjektStudio.ContentBlock.Crud.updateContentBlock(
      contentBlock,
      content
    );

    this.exitAiEditMode(contentBlockWrapper);
  },

  submitPrompt(e) {
    const { contentBlockWrapper } = ProjektStudio.ContentBlock.DomHelpers.getContentBlockAndWrapper(e.target);
    const popup = this.getPopup(contentBlockWrapper);
    const submitButton = popup.querySelector('.js-content-block-ai-edit--submit-prompt');
    const instructionsTextarea = popup.querySelector('.js-ai-instructions-textarea');
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    if (this.activeAjaxRequests[contentBlockId]) {
      this.activeAjaxRequests[contentBlockId].abort();
      delete this.activeAjaxRequests[contentBlockId];

      submitButton.disabled = false;
      this.setButtonState(submitButton, 'submit');
      instructionsTextarea.disabled = false;
      return;
    }

    const instructions = instructionsTextarea.value.trim();

    if (!instructionsTextarea.reportValidity()) return

    const contentBlock = ProjektStudio.ContentBlock.DomHelpers.getContentBlock(contentBlockWrapper);

    this.setLoadingState(contentBlockWrapper, popup, true);

    const ajaxRequest = $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${contentBlockId}/change_with_ai`,
      type: "PATCH",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded,
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      data: {
        instructions: instructions,
        content_block_html: contentBlock.innerHTML
      }
    });

    this.activeAjaxRequests[contentBlockId] = ajaxRequest;

    setTimeout(() => {
      if (this.activeAjaxRequests[contentBlockId] === ajaxRequest) {
        submitButton.disabled = false;
        this.setButtonState(submitButton, 'cancel');
        instructionsTextarea.disabled = true;
      }
    }, 550);

    ajaxRequest
    .then((response) => {
      this.handleSuccessResponse(response, contentBlock);
      instructionsTextarea.value = ""
    })
    .catch((response) => {
      if (response.statusText !== 'abort') {
        this.handleErrorResponse(response);
      }
    })
    .always(() => {
      delete this.activeAjaxRequests[contentBlockId];
      this.setLoadingState(contentBlockWrapper, popup, false);

      instructionsTextarea.disabled = false
    });
  },

  handleSuccessResponse(response, contentBlock) {
    if (response.content_block_html) {
      if (contentBlock) {
        contentBlock.innerHTML = response.content_block_html;

        $(contentBlock).foundation();
        App.ImageGallery.initialize();
      }
    } else {
      this.showErrorMessage('Ungültige Antwort vom Server');
    }
  },

  handleErrorResponse(response) {
    let errorMessage = 'Fehler beim Aktualisieren des Inhaltsblocks';

    if (response.responseJSON && response.responseJSON.message) {
      errorMessage = response.responseJSON.message;
    } else if (response.statusText) {
      errorMessage = `${errorMessage}: ${response.statusText}`;
    }

    this.showErrorMessage(errorMessage);
  },

  setLoadingState(contentBlockWrapper, popup, isLoading) {
    if (!contentBlockWrapper || !popup) return;

    const popupSubmitButton = popup.querySelector('.js-content-block-ai-edit--submit-prompt');
    const popupLoader = popup.querySelector('.ai-edit-mode--loader');
    const toolbarSaveButton = contentBlockWrapper.querySelector('.js-ai-edit-mode-controlls .js-content-block-ai-edit-save');
    const toolbarSwitchToSimpleButton = contentBlockWrapper.querySelector('.js-ai-edit-mode-controlls .js-content-block-enter-simple-edit-mode-from-ai');
    const instructionsTextarea = popup.querySelector('.js-ai-instructions-textarea');
    const toolbarLoader = contentBlockWrapper.querySelector('.ai-edit-mode--loader');

    popupSubmitButton.disabled = isLoading;
    popupSubmitButton.classList.toggle("-green", !isLoading)

    if (!isLoading) {
      this.setButtonState(popupSubmitButton, 'submit');
    }
    popupLoader.style.display = isLoading ? 'block' : 'none';
    toolbarSaveButton.disabled = isLoading;
    toolbarSwitchToSimpleButton.disabled = isLoading;
    instructionsTextarea.disabled = isLoading;
    toolbarLoader.style.display = isLoading ? 'block' : 'none';
  },

  showSuccessMessage(message) {
    alert(message);
  },

  showErrorMessage(message) {
    alert(message);
  },

  setButtonState(button, state) {
    const isRunning = state === 'cancel';
    button.classList.toggle('-running', isRunning);
    button.classList.toggle('-green', !isRunning);
  }
};

