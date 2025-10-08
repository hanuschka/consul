ProjektStudio.ContentBlockSimpleEdit.ImageGalleryDialog = {
  state: {
    type: 'picture',
    page: 1,
    search: '',
    total_pages: 0,
    items: [],
    chosen: null,
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

    $document.on("click", ".js-cb-img-select", this.handleSelectClick.bind(this));
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
      chosen: null,
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
    this.state.chosen = null;
    this.onSelectCallback = null;
    this.contentBlockId = null;
    this.contentBlockWrapper = null;

    // Reset button states
    this.updateSelectButtonState();
  },

  handleSearchInputType(e) {
    this.state.search = e.target.value;

    // if (this.state.search.length >= 2 || this.state.search.length === 0) {
    this.debouncedSearch();
    // }
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
        const formData = new FormData();
        formData.append('upload', files[0]);

        this.uploadNewImage(formData);
      }
    });

    fileInput.click();
  },

  handleItemClick(e) {
    const item = e.currentTarget;
    const itemId = parseInt(item.dataset.id);
    const selectedItem = this.state.items.find(i => i.id === itemId);

    if (selectedItem) {
      if (this.state.chosen && this.state.chosen.id === itemId) {
        this.state.chosen = null;
      } else {
        this.state.chosen = selectedItem;
      }

      this.updateItemsUI();
      this.updateEditButtonVisibility();
      this.updateSelectButtonState();
    }
  },

  handleSelectClick(e) {
    e.preventDefault();

    if (!this.state.chosen) {
      return;
    }

    if (this.onSelectCallback && typeof this.onSelectCallback === 'function') {
      this.onSelectCallback(this.state.chosen);
    }

    this.closeDialog();
  },

  fetchImages() {
    this.state.isLoading = true;
    this.updateItemsUI();
    this.updatePagination();

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    fetch('/ckeditor/assets', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': csrfToken
      },
      body: JSON.stringify({
        type: this.state.type,
        page: this.state.page,
        search: this.state.search
      })
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

  uploadNewImage(formData) {
    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    // Track loading state if we have content block context
    if (this.contentBlockId && this.contentBlockWrapper) {
      ProjektStudio.ContentBlockSimpleEdit.ImageEdit.incrementImageLoadingCount(this.contentBlockId);
      ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(this.contentBlockWrapper, true);
    }

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
        } else {
          this.state.items.unshift(resp);
          this.updateItemsUI();
        }
      })
      .catch(error => {
        console.error('Error uploading image:', error);
        alert('Fehler beim Hochladen des Bildes');
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
    const isActive = this.state.chosen && this.state.chosen.id === item.id;
    const imageSrc = item.thumb_url || item.url;
    const imageAlt = item.alt_text || item.title || 'Image';
    const title = item.title || item.data_file_name || 'Untitled';
    const altText = item.alt_text || '';
    const isImage = item.data_content_type && item.data_content_type.startsWith('image/');

    const template = `
      <div class="cb-img-dialog__item ${isActive ? '-active' : ''}" data-id="${item.id}">
        <div class="cb-img-dialog__item-thumb">
          ${isImage ? `<img src="${imageSrc}" alt="${imageAlt}">` : ''}
        </div>
        <div class="cb-img-dialog__item-meta">
          <p class="cb-img-dialog__item-title" title="${title}">${title}</p>
          <div class="cb-img-dialog__item-alt">${altText}</div>
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
      editBtn.style.display = this.state.chosen ? 'block' : 'none';
    }
  },

  updateSelectButtonState() {
    const selectBtn = document.querySelector(".js-cb-img-select");
    if (selectBtn) {
      const hasSelection = this.state.chosen && Object.keys(this.state.chosen).length > 0;
      selectBtn.disabled = !hasSelection;
    }
  },

  openEditModal(e) {
    e.preventDefault();

    if (!this.state.chosen) return;

    const modal = document.querySelector(".js-cb-img-edit-modal");
    if (!modal) return;

    modal.classList.add("-active");

    const titleInput = modal.querySelector(".js-cb-img-edit-title");
    const descInput = modal.querySelector(".js-cb-img-edit-description");
    const altInput = modal.querySelector(".js-cb-img-edit-alt");

    if (titleInput) titleInput.value = this.state.chosen.title || '';
    if (descInput) descInput.value = this.state.chosen.description || '';
    if (altInput) altInput.value = this.state.chosen.alt_text || '';
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

    if (!this.state.chosen) return;

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

    fetch(`/ckeditor/pictures/${this.state.chosen.id}`, {
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
            this.state.chosen = chosenArr[0];
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

    if (!this.state.chosen) return;

    if (!confirm('Möchten Sie dieses Bild wirklich löschen?')) {
      return;
    }

    const chosenId = this.state.chosen.id;
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
          this.state.chosen = null;
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

