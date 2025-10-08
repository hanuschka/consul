ProjektStudio.ContentBlockSimpleEdit.ImageGalleryDialog = {
  state: {
    type: 'picture',
    page: 1,
    search: '',
    total_pages: 0,
    items: [],
    selectedImage: null,
    isLoading: false
  },
  onSelectCallback: null,
  contentBlockId: null,
  contentBlockWrapper: null,

  initialize() {
    this.initEventListeners()
    this.initDebouncedSearch()
  },

  initDebouncedSearch() {
    this.debouncedSearch = ProjektStudio.utils.debounce(() => {
      this.performSearch();
    }, 200);
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-cb-img-dialog-close", this.closeDialog.bind(this));

    $document.on("input", ".js-cb-img-search", this.handleSearchInputType.bind(this));
    $document.on("keydown", ".js-cb-img-search", this.handleSearchKeydown.bind(this));
    $document.on("click", ".js-cb-img-search-clear", this.clearSearch.bind(this));

    $document.on("click", ".js-cb-img-filter", this.handleFilterClick.bind(this));
    $document.on("click", ".js-cb-img-upload", this.handleUpload.bind(this));

    $document.on("click", ".js-cb-img-edit", this.openEditModal.bind(this));
    $document.on("click", ".js-cb-img-edit-close", this.closeEditModal.bind(this));
    $document.on("click", ".js-cb-img-update", this.updateImage.bind(this));
    $document.on("click", ".js-cb-img-delete", this.deleteImage.bind(this));

    $document.on("click", ".js-cb-img-select", this.handleImageSelected.bind(this));
    $document.on("click", ".cb-img-dialog__item", this.handleItemClick.bind(this));
    $document.on("click", ".js-cb-img-page-btn", this.handlePaginationClick.bind(this));
  },

  openDialog(onSelectCallback, contentBlockId = null, contentBlockWrapper = null) {
    this.onSelectCallback = onSelectCallback;
    this.contentBlockId = contentBlockId;
    this.contentBlockWrapper = contentBlockWrapper;

    this.state = {
      type: 'picture',
      page: 1,
      search: '',
      total_pages: 0,
      items: [],
      selectedImage: null,
      isLoading: false
    };

    const dialog = document.querySelector(".js-cb-img-dialog");
    if (!dialog) {
      console.error('Image gallery dialog not found in DOM');
      return;
    }

    dialog.classList.add("-active");

    const searchInput = document.querySelector(".js-cb-img-search");
    if (searchInput) {
      searchInput.value = '';
    }

    this.updateEditButtonVisibility();
    this.updateSelectButtonState();
    this.fetchImages();
  },

  closeDialog(e) {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    const dialog = document.querySelector(".js-cb-img-dialog");
    if (dialog) {
      dialog.classList.remove("-active");
    }

    // Reset state
    this.state.selectedImage = null;
    this.onSelectCallback = null;
    this.contentBlockId = null;
    this.contentBlockWrapper = null;

    this.updateSelectButtonState();
  },

  handleSearchInputType(e) {
    this.state.search = e.target.value;

    this.debouncedSearch();
  },

  handleSearchKeydown(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      this.performSearch();
    }
  },

  performSearch() {
    if (this.state.search.length >= 2 || this.state.search.length === 0) {
      this.state.page = 1;
      this.fetchImages();
    }
  },

  clearSearch(e) {
    e.preventDefault();
    const searchInput = document.querySelector(".js-cb-img-search");
    if (searchInput) {
      searchInput.value = '';
    }
    this.state.search = '';
    this.performSearch();
  },

  handleFilterClick(e) {
    e.preventDefault();
    const type = e.currentTarget.dataset.type;

    if (type !== this.state.type) {
      this.state.type = type;
      this.state.page = 1;

      document.querySelectorAll(".js-cb-img-filter").forEach(btn => {
        btn.classList.remove("active");
      });
      e.currentTarget.classList.add("active");

      this.fetchImages();
    }
  },

  handleUpload(e) {
    e.preventDefault();

    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.accept = 'image/*';

    fileInput.addEventListener('change', (event) => {
      const files = event.target.files;
      if (files && files.length > 0) {
        const file = files[0];

        // Create a preview using FileReader
        const reader = new FileReader();
        reader.onload = (e) => {
          const previewUrl = e.target.result;

          // Create temporary item with preview
          const tempItem = {
            id: `temp-${Date.now()}`,
            thumb_url: previewUrl,
            url: previewUrl,
            title: file.name,
            data_file_name: file.name,
            alt_text: '',
            description: '',
            data_content_type: file.type,
            isUploading: true
          };

          // Add to beginning of items
          this.state.items.unshift(tempItem);
          this.updateItemsUI();

          // Start upload
          const formData = new FormData();
          formData.append('upload', file);
          this.uploadNewImage(formData, tempItem.id);
        };

        reader.readAsDataURL(file);
      }
    });

    fileInput.click();
  },

  handleItemClick(e) {
    const item = e.currentTarget;
    const itemId = item.dataset.id;
    // Handle both numeric IDs and temp string IDs
    const selectedItem = this.state.items.find(i => String(i.id) === String(itemId));

    if (selectedItem) {
      if (this.state.selectedImage && String(this.state.selectedImage.id) === String(itemId)) {
        this.state.selectedImage = null;
      } else {
        this.state.selectedImage = selectedItem;
      }

      this.updateItemsUI();
      this.updateEditButtonVisibility();
      this.updateSelectButtonState();
    }
  },

  handleImageSelected() {
    if (!this.state.selectedImage) return

    if (this.onSelectCallback && typeof this.onSelectCallback === 'function') {
      this.onSelectCallback(this.state.selectedImage);
    }

    this.closeDialog();
  },

  fetchImages() {
    this.state.isLoading = true;
    this.updateItemsUI();
    this.updatePagination();

    const { type, page, search } = this.state;

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    fetch(`/ckeditor/assets?${new URLSearchParams({ type, page, search })}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': csrfToken
      }
    })
      .then(response => response.json())
      .then(data => {
        this.state.total_pages = data.total_pages;
        this.state.items = data.items;
      })
      .catch(error => {
        console.error('Error fetching images:', error);
        alert('Fehler beim Laden der Bilder');
      })
      .finally(() => {
        this.state.isLoading = false;
        this.updateItemsUI();
        this.updatePagination();
      });
  },

  uploadNewImage(formData, tempItemId) {
    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    // Track loading state if we have content block context
    if (this.contentBlockId && this.contentBlockWrapper) {
      ProjektStudio.ContentBlockSimpleEdit.ImageEdit.incrementImageLoadingCount(this.contentBlockId);
      ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(this.contentBlockWrapper, true);
    }

    return
    fetch('/ckeditor/pictures', {
      method: 'POST',
      headers: {
        'X-CSRF-TOKEN': csrfToken
      },
      body: formData
    })
      .then(response => response.json())
      .then(resp => {
        if (resp.error) {
          alert(resp.error.message);
          // Remove temp item on error
          this.state.items = this.state.items.filter(item => String(item.id) !== String(tempItemId));
          // Clear selection if the failed upload was selected
          if (this.state.selectedImage && String(this.state.selectedImage.id) === String(tempItemId)) {
            this.state.selectedImage = null;
            this.updateEditButtonVisibility();
            this.updateSelectButtonState();
          }
        } else {
          // Replace temp item with real uploaded item, add previewUrl
          const uploadedItem = {
            ...resp,
            previewUrl: resp.thumb_url || resp.url
          };

          const index = this.state.items.findIndex(item => String(item.id) === String(tempItemId));
          if (index !== -1) {
            this.state.items[index] = uploadedItem;

            // If the temp item was selected, update selectedImage to the real item
            if (this.state.selectedImage && String(this.state.selectedImage.id) === String(tempItemId)) {
              this.state.selectedImage = uploadedItem;
              this.updateEditButtonVisibility();
              this.updateSelectButtonState();
            }
          }
        }
        this.updateItemsUI();
      })
      .catch(error => {
        console.error('Error uploading image:', error);
        alert('Fehler beim Hochladen des Bildes');
        // Remove temp item on error
        this.state.items = this.state.items.filter(item => String(item.id) !== String(tempItemId));
        // Clear selection if the failed upload was selected
        if (this.state.selectedImage && String(this.state.selectedImage.id) === String(tempItemId)) {
          this.state.selectedImage = null;
          this.updateEditButtonVisibility();
          this.updateSelectButtonState();
        }
        this.updateItemsUI();
      })
      .finally(() => {
        if (this.contentBlockId && this.contentBlockWrapper) {
          ProjektStudio.ContentBlockSimpleEdit.ImageEdit.decrementImageLoadingCount(this.contentBlockId);

          const loadingState = ProjektStudio.ContentBlockSimpleEdit.ImageEdit.contentBlockImageLoadingState;
          if (loadingState[this.contentBlockId] <= 0) {
            ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(this.contentBlockWrapper, false);
          }
        }
      });
  },

  updateItemsUI() {
    const grid = document.querySelector(".js-cb-img-grid");
    if (!grid) return;

    if (this.state.isLoading) {
      grid.innerHTML = `
        <div class="loading-spinner-inline -gray cb-loading-spinner"></div>
      `;
      return;
    }

    if (this.state.items.length === 0) {
      grid.innerHTML = '<div class="cb-img-dialog__loading">Keine Bilder gefunden.</div>';
      return;
    }

    grid.innerHTML = '';

    this.state.items.forEach(item => {
      this.renderImageItem(item, grid)
    });
  },

  renderImageItem(item, grid) {
    const isActive = this.state.selectedImage && String(this.state.selectedImage.id) === String(item.id);
    const isUploading = item.isUploading === true;
    const imageSrc = item.thumb_url || item.url;
    const imageAlt = item.alt_text || item.title || 'Image';
    const title = item.title || item.data_file_name || 'Untitled';
    const altText = item.alt_text || '';
    const isImage = item.data_content_type && item.data_content_type.startsWith('image/');

    const template = `
      <div class="cb-img-dialog__item ${isActive ? '-active' : ''} ${isUploading ? '-uploading' : ''}" data-id="${item.id}">
        <div class="cb-img-dialog__item-thumb">
          <div class="cb-img-dialog__item-thumb-overlay-backdrop"></div>
          ${isImage ? `<img src="${imageSrc}" alt="${imageAlt}">` : ''}
          ${isUploading ? '<div class="cb-img-dialog__item-uploading"><div class="loading-spinner-inline"></div></div>' : ''}
        </div>
        <div class="cb-img-dialog__item-meta">
          <p class="cb-img-dialog__item-title" title="${title}">${title}</p>
          <div class="cb-img-dialog__item-alt">${isUploading ? 'Wird hochgeladen...' : altText}</div>
        </div>
      </div>
    `;

    grid.insertAdjacentHTML('beforeend', template);
  },

  updatePagination() {
    const pagination = document.querySelector(".js-cb-img-pagination");
    if (!pagination) return;

    if (this.state.isLoading) {
      return;
    }

    if (this.state.total_pages < 2) {
      pagination.innerHTML = '';
      return;
    }

    const currentPage = this.state.page;
    const totalPages = this.state.total_pages;
    const isFirstPage = currentPage === 1;
    const isLastPage = currentPage === totalPages;

    const buttons = [];

    // First button
    buttons.push(`
      <button
        type="button"
        class="cb-img-dialog__page-btn cb-img-dialog__page-btn--nav cb-img-dialog__page-btn--text js-cb-img-page-btn"
        data-page="1"
        ${isFirstPage ? 'disabled' : ''}
        title="Erste Seite"
      >
        <i class="fa fa-angles-left"></i>
        <span>Erste</span>
      </button>
    `);

    // Previous button
    buttons.push(`
      <button
        type="button"
        class="cb-img-dialog__page-btn cb-img-dialog__page-btn--nav js-cb-img-page-btn"
        data-page="${currentPage - 1}"
        ${isFirstPage ? 'disabled' : ''}
        title="Vorherige Seite"
      >
        <i class="fa fa-angle-left"></i>
      </button>
    `);

    // Page number buttons
    for (let i = 1; i <= totalPages; i++) {
      const isActive = i === currentPage;
      buttons.push(`
        <button
          type="button"
          class="cb-img-dialog__page-btn js-cb-img-page-btn ${isActive ? '-active' : ''}"
          data-page="${i}"
          ${isActive ? 'disabled' : ''}
        >
          ${i}
        </button>
      `);
    }

    // Next button
    buttons.push(`
      <button
        type="button"
        class="cb-img-dialog__page-btn cb-img-dialog__page-btn--nav js-cb-img-page-btn"
        data-page="${currentPage + 1}"
        ${isLastPage ? 'disabled' : ''}
        title="Nächste Seite"
      >
        <i class="fa fa-angle-right"></i>
      </button>
    `);

    // Last button
    buttons.push(`
      <button
        type="button"
        class="cb-img-dialog__page-btn cb-img-dialog__page-btn--nav cb-img-dialog__page-btn--text js-cb-img-page-btn"
        data-page="${totalPages}"
        ${isLastPage ? 'disabled' : ''}
        title="Letzte Seite"
      >
        <span>Letzte</span>
        <i class="fa fa-angles-right"></i>
      </button>
    `);

    pagination.innerHTML = buttons.join('');
  },

  handlePaginationClick(e) {
    const pageNumber = parseInt(e.currentTarget.dataset.page);

    if (pageNumber && pageNumber !== this.state.page) {
      $(".js-cb-img-page-btn.-active").removeClass("-active").prop("disabled", false)
      $(`.js-cb-img-page-btn[data-page=${pageNumber}]`).addClass("-active").prop("disabled", true)

      this.state.page = pageNumber;
      this.fetchImages();
    }
  },

  updateEditButtonVisibility() {
    const editBtn = document.querySelector(".js-cb-img-edit");
    if (editBtn) {
      editBtn.style.display = this.state.selectedImage ? 'block' : 'none';
    }
  },

  updateSelectButtonState() {
    const selectBtn = document.querySelector(".js-cb-img-select");
    if (selectBtn) {
      const hasSelection = this.state.selectedImage && Object.keys(this.state.selectedImage).length > 0;
      const isChosenUploading = this.state.selectedImage && this.state.selectedImage.isUploading === true;

      // Disable if no selection OR if selected item is still uploading
      selectBtn.disabled = !hasSelection || isChosenUploading;
    }
  },

  openEditModal(e) {
    e.preventDefault();

    if (!this.state.selectedImage) return;

    const modal = document.querySelector(".js-cb-img-edit-modal");
    if (!modal) return;

    modal.classList.add("-active");

    const titleInput = modal.querySelector(".js-cb-img-edit-title");
    const descInput = modal.querySelector(".js-cb-img-edit-description");
    const altInput = modal.querySelector(".js-cb-img-edit-alt");

    if (titleInput) titleInput.value = this.state.selectedImage.title || '';
    if (descInput) descInput.value = this.state.selectedImage.description || '';
    if (altInput) altInput.value = this.state.selectedImage.alt_text || '';
  },

  closeEditModal(e) {
    if (e) {
      e.preventDefault();
      e.stopPropagation();
    }

    const modal = document.querySelector(".js-cb-img-edit-modal");
    if (modal) {
      modal.classList.remove("-active");
    }
  },

  updateImage(e) {
    e.preventDefault();

    if (!this.state.selectedImage) return;

    const modal = document.querySelector(".js-cb-img-edit-modal");
    if (!modal) return;

    const titleInput = modal.querySelector(".js-cb-img-edit-title");
    const descInput = modal.querySelector(".js-cb-img-edit-description");
    const altInput = modal.querySelector(".js-cb-img-edit-alt");

    const formData = new FormData();
    formData.append(`${this.state.type}[title]`, titleInput.value);
    formData.append(`${this.state.type}[description]`, descInput.value);
    formData.append(`${this.state.type}[alt_text]`, altInput.value);

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    fetch(`/ckeditor/pictures/${this.state.selectedImage.id}`, {
      method: 'PATCH',
      headers: {
        'X-CSRF-TOKEN': csrfToken
      },
      body: formData
    })
      .then(response => response.json())
      .then(data => {
        if (data.id) {
          // Update the item in state
          this.state.items = this.state.items.map(o => o.id === data.id ? data : o);
          const chosenArr = this.state.items.filter(o => o.id === data.id);
          if (chosenArr.length) {
            this.state.selectedImage = chosenArr[0];
          }
          this.updateItemsUI();
          this.closeEditModal();
        }
      })
      .catch(error => {
        console.error('Error updating image:', error);
        alert('Fehler beim Aktualisieren des Bildes');
      });
  },

  deleteImage(e) {
    e.preventDefault();

    if (!this.state.selectedImage) return;

    if (!confirm('Möchten Sie dieses Bild wirklich löschen?')) {
      return;
    }

    const chosenId = this.state.selectedImage.id;
    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    fetch(`/ckeditor/pictures/${chosenId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-TOKEN': csrfToken
      }
    })
      .then(response => response.json())
      .then(data => {
        if (data.status && data.status === 'no_content') {
          this.state.items = this.state.items.filter(o => o.id !== chosenId);
          this.state.selectedImage = null;
          this.updateItemsUI();
          this.updatePagination();
          this.updateEditButtonVisibility();
          this.closeEditModal();
        }
      })
      .catch(error => {
        console.error('Error deleting image:', error);
        alert('Fehler beim Löschen des Bildes');
      });
  }
}

