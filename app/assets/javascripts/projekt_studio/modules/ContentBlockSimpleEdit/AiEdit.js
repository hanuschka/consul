ProjektStudio.ContentBlockSimpleEdit.AiEdit = {
  initialized: false,
  modalId: 'ai-edit-modal',
  currentContentBlockId: null,
  currentContentBlockWrapper: null,

  initialize() {
    this.initEventListeners()
    this.createModal()
  },

  initEventListeners() {
    const $document = $(document);
    $document.on("click", ".js-ai-edit-content-block", this.openAiEditModal.bind(this));
    $document.on("click", ".js-ai-edit-submit", this.submitAiEdit.bind(this));
    $document.on("click", ".js-ai-edit-cancel", this.closeAiEditModal.bind(this));
    $document.on("click", ".js-ai-edit-modal-backdrop", this.closeAiEditModal.bind(this));
  },

  createModal() {
    // Check if modal already exists
    if (document.getElementById(this.modalId)) {
      return;
    }

    const modalHtml = `
      <div id="${this.modalId}" class="reveal modern-modal ai-edit-modal" data-reveal>
        <div class="modern-modal-content ai-edit-modal-content">
          <h3>Edit with AI</h3>
          <div class="ai-edit-form">
            <label for="ai-instructions">Instructions:</label>
            <textarea
              id="ai-instructions"
              name="instructions"
              rows="4"
              placeholder="Enter your instructions for editing this content block..."
              class="ai-instructions-textarea"
            ></textarea>
          </div>
          <div class="ai-edit-actions">
            <button type="button" class="projekt-content-block-edit--button -green js-ai-edit-submit">
              <i class="fas fa-magic"></i>
              Submit
            </button>
            <button type="button" class="projekt-content-block-edit--button js-ai-edit-cancel">
              <i class="fas fa-times"></i>
              Cancel
            </button>
          </div>
        </div>
        <button class="close-button button -round-icon-button" data-close aria-label="Close Accessible Modal" type="button">
          <i class="fa fa-xmark">
          </i>
        </button>
      </div>
    `;

    document.body.insertAdjacentHTML('beforeend', modalHtml);

    $(`#${this.modalId}`).foundation();
  },

  openAiEditModal(e) {
    e.preventDefault();

    const contentBlockWrapper = this.getParentContentBlockWrapper(e.target);
    const contentBlockId = contentBlockWrapper.dataset.contentBlockId;

    if (!contentBlockId) {
      alert('Content block ID not found');
      return;
    }

    this.currentContentBlockId = contentBlockId;
    this.currentContentBlockWrapper = contentBlockWrapper;

    const instructionsTextarea = document.getElementById('ai-instructions');
    instructionsTextarea.value = '';

    $(`#${this.modalId}`).foundation('open');

    setTimeout(() => { instructionsTextarea.focus()}, 100);
  },

  closeAiEditModal() {
    $(`#${this.modalId}`).foundation('close');
    this.currentContentBlockId = null;
    this.currentContentBlockWrapper = null;
  },

  cleanHtmlForBackend(html) {
    const tempDiv = document.createElement('div');
    tempDiv.innerHTML = html;

    // Remove all simple edit controls
    const controlsToRemove = [
      // List edit controls
      '.js-content-block--list-control',
      '.js-content-block--list-add',
      '.js-content-block--list-remove',
      '.js-content-block--list-move-up',
      '.js-content-block--list-move-down',

      // Image edit controls
      '.js-content-block--image-edit',
      '.js-content-block--image-remove',
      '.js-content-block--image-gallery-edit',

      // Link edit controls
      '.js-content-block--link-edit',
      '.js-content-block--link-remove',

      // Other simple edit controls
      '.js-content-block--text-edit',
      '.js-content-block--edit-controls',
      '.js-content-block--editable',

      // Generic edit control classes
      '.content-block-edit-control',
      '.edit-control',
      '.js-edit-control'
    ];

    controlsToRemove.forEach(selector => {
      const elements = tempDiv.querySelectorAll(selector);
      elements.forEach(element => element.remove());
    });

    // Remove any elements with data attributes that indicate edit controls
    const editElements = tempDiv.querySelectorAll('[data-edit-control], [data-simple-edit], [data-list-edit], [data-image-edit], [data-link-edit]');
    editElements.forEach(element => element.remove());

    // Remove any elements with classes that contain 'edit' and are likely controls
    const allElements = tempDiv.querySelectorAll('*');
    allElements.forEach(element => {
      const classList = Array.from(element.classList);
      const hasEditClass = classList.some(cls =>
        cls.includes('edit') && (
          cls.includes('control') ||
          cls.includes('button') ||
          cls.includes('tool') ||
          cls.includes('action')
        )
      );

      if (hasEditClass && element.tagName !== 'TEXTAREA' && element.tagName !== 'INPUT') {
        element.remove();
      }
    });

    return tempDiv.innerHTML;
  },

  submitAiEdit() {
    const instructionsTextarea = document.getElementById('ai-instructions');
    const instructions = instructionsTextarea ? instructionsTextarea.value.trim() : '';

    if (!instructions) {
      alert('Please enter instructions for the AI');
      return;
    }

    if (!this.currentContentBlockId) {
      alert('No content block selected');
      return;
    }

    const contentBlock = this.currentContentBlockWrapper.querySelector('.projekt-content-block');
    const rawHtml = contentBlock ? contentBlock.innerHTML : '';
    const cleanedHtml = this.cleanHtmlForBackend(rawHtml);

    this.showLoadingState();

    $.ajax({
      url: `/${App.routeNamespace}/projekt_content_blocks/${this.currentContentBlockId}/change_with_ai`,
      type: "PATCH",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded,
        'X-CSRF-Token': $('meta[name="csrf-token"]').attr('content')
      },
      data: {
        instructions: instructions,
        content_block_html: cleanedHtml
      }
    })
    .then((response) => {
      this.handleSuccessResponse(response);
    })
    .catch((response) => {
      this.handleErrorResponse(response);
    })
    .always(() => {
      this.hideLoadingState();
    });
  },

  handleSuccessResponse(response) {
    if (response.content_block_html) {
      const contentBlock = this.currentContentBlockWrapper.querySelector('.projekt-content-block');
      if (contentBlock) {
        // ProjektStudio.ContentBlocks.storePreviousVersionOfContentBlock(
        //   contentBlock,
        //   this.currentContentBlockWrapper
        // );

        contentBlock.innerHTML = response.content_block_html;

        $(contentBlock).foundation();
        App.ImageGallery.initialize();

        this.closeAiEditModal();

        // this.showSuccessMessage('Content block updated successfully');
      }
    } else {
      this.showErrorMessage('Invalid response from server');
    }
  },

  handleErrorResponse(response) {
    let errorMessage = 'Error updating content block';

    if (response.responseJSON && response.responseJSON.message) {
      errorMessage = response.responseJSON.message;
    } else if (response.statusText) {
      errorMessage = `${errorMessage}: ${response.statusText}`;
    }

    this.showErrorMessage(errorMessage);
  },

  showLoadingState() {
    const submitButton = document.querySelector('.js-ai-edit-submit');
    const cancelButton = document.querySelector('.js-ai-edit-cancel');
    const instructionsTextarea = document.getElementById('ai-instructions');

    if (submitButton) {
      submitButton.disabled = true;
      submitButton.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Processing...';
    }

    if (cancelButton) {
      cancelButton.disabled = true;
    }

    if (instructionsTextarea) {
      instructionsTextarea.disabled = true;
    }
  },

  hideLoadingState() {
    const submitButton = document.querySelector('.js-ai-edit-submit');
    const cancelButton = document.querySelector('.js-ai-edit-cancel');
    const instructionsTextarea = document.getElementById('ai-instructions');

    if (submitButton) {
      submitButton.disabled = false;
      submitButton.innerHTML = '<i class="fas fa-magic"></i> Submit';
    }

    if (cancelButton) {
      cancelButton.disabled = false;
    }

    if (instructionsTextarea) {
      instructionsTextarea.disabled = false;
    }
  },

  showSuccessMessage(message) {
    alert(message);
  },

  showErrorMessage(message) {
    alert(message);
  },

  getParentContentBlockWrapper(element) {
    return element.closest('.js-projekt-content-block-wrapper');
  }
};
