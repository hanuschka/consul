ProjektStudio.ContentBlockSimpleEdit.ImageGalleryDialog = {
  state: {
    type: 'picture',
    page: 1,
    search: '',
    selectedImage: null,
    isLoading: false,
    uploadingCount: 0
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
    $document.on("click", ".js-cb-img-upload", this.handleUploadButtonClick.bind(this));

    $document.on("click", ".js-cb-img-edit", this.openEditModal.bind(this));
    $document.on("click", ".js-cb-img-edit-close", this.closeEditModal.bind(this));
    $document.on("click", ".js-cb-img-update", this.updateImage.bind(this));
    $document.on("click", ".js-cb-img-delete", this.deleteImage.bind(this));

    $document.on("click", ".js-cb-img-select", this.handleImageSelected.bind(this));
    $document.on("click", ".cb-img-dialog__item", this.handleItemClick.bind(this));
    $document.on("click", ".pagination a", this.handleKaminariPaginationClick.bind(this));
  },

  openDialog(onSelectCallback, contentBlockId = null, contentBlockWrapper = null) {
    this.onSelectCallback = onSelectCallback;
    this.contentBlockId = contentBlockId;
    this.contentBlockWrapper = contentBlockWrapper;

    this.state = {
      type: 'picture',
      page: 1,
      search: '',
      selectedImage: null,
      isLoading: false,
      uploadingCount: 0
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
    this.fetchImageItems();
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

  incrementUploadingCount() {
    this.state.uploadingCount++;
    this.updateUploadingState();
  },

  decrementUploadingCount() {
    this.state.uploadingCount = Math.max(0, this.state.uploadingCount - 1);
    this.updateUploadingState();
  },

  updateUploadingState() {
    const isUploading = this.state.uploadingCount > 0;
    const searchInput = document.querySelector('.js-cb-img-search');
    const pagination = document.querySelector('.js-cb-img-pagination');

    searchInput.disabled = isUploading;

    if (pagination) {
      // console.log("update pagination", pagination)
      // console.log("isUploading", isUploading)
      // console.log("this.state.uploadingCount", this.state.uploadingCount)
      pagination.classList.toggle('-disabled', isUploading);
      $(".js-cb-img-page-btn").prop("disabled", isUploading)
      $(`.js-cb-img-page-btn[data-page=${this.state.page}]`).prop("disabled", true)
    }
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
      this.fetchImageItems();
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

      this.fetchImageItems();
    }
  },

  navigateToPage(pageNumber, navigationResolvedCallback) {
    if (pageNumber && pageNumber !== this.state.page) {
      $(".js-cb-img-page-btn.-active").removeClass("-active").prop("disabled", false)
      $(`.js-cb-img-page-btn[data-page=${pageNumber}]`).addClass("-active").prop("disabled", true)

      this.state.page = pageNumber;
      this.fetchImageItems(navigationResolvedCallback)
    }
    else if (pageNumber === this.state.page) {
      navigationResolvedCallback()
    }
  },

  handleUploadButtonClick(_e) {
    const fileInput = document.createElement('input');
    fileInput.type = 'file';
    fileInput.accept = 'image/*';

    fileInput.addEventListener('change', (event) => {
      this.navigateToPage(1, () => {
        const files = event.target.files;

        if (files && files.length > 0) {
          const file = files[0];

          const reader = new FileReader();
          reader.onload = (e) => {
            const inMemoryPreviewUrl = e.target.result;

            // Create temporary item with preview
            const tempItem = {
              id: `temp-${Date.now()}`,
              in_memory_preview_url: inMemoryPreviewUrl,
              title: file.name,
              data_file_name: file.name,
              alt_text: '',
              description: '',
              data_content_type: file.type,
              isUploading: true
            };



            const formData = new FormData();
            formData.append('upload', file);
            this.uploadNewImage(formData, tempItem.id);
          };

          reader.readAsDataURL(file);
        }
      });
    })

    fileInput.click();
  },

  handleItemClick(e) {
    const item = e.currentTarget;
    const itemId = item.dataset.id;

    // Toggle selection
    if (this.state.selectedImage && String(this.state.selectedImage.id) === String(itemId)) {
      this.state.selectedImage = null;
    } else {
      // Create a minimal selected image object from DOM data
      this.state.selectedImage = {
        id: itemId,
        title: item.querySelector('.cb-img-dialog__item-title')?.textContent || '',
        alt_text: item.querySelector('.cb-img-dialog__item-alt')?.textContent || ''
      };
    }

    this.updateEditButtonVisibility();
    this.updateSelectButtonState();
  },

  handleImageSelected() {
    if (!this.state.selectedImage) return

    if (this.onSelectCallback && typeof this.onSelectCallback === 'function') {
      this.onSelectCallback(this.state.selectedImage);
    }

    this.closeDialog();
  },

  fetchImageItems(fetchCallback) {
    this.state.isLoading = true;

    const { type, page, search } = this.state;

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    return fetch(`/ckeditor/pictures?${new URLSearchParams({ type, page, search })}`, {
      method: 'GET',
      headers: {
        'Accept': 'text/html',
        'X-CSRF-TOKEN': csrfToken
      }
    })
      .then(response => response.text())
      .then(html => {
        // Parse the HTML response to extract body content
        const parser = new DOMParser();
        const doc = parser.parseFromString(html, 'text/html');
        const bodyContent = doc.querySelector('.cb-img-dialog__body');

        if (bodyContent) {
          // Update the dialog body with the complete content
          const dialogBody = document.querySelector('.cb-img-dialog__body');
          if (dialogBody) {
            dialogBody.innerHTML = bodyContent.innerHTML;
          }
        }


        if (fetchCallback) {
          fetchCallback()
        }
      })
      .catch(error => {
        console.error('Error fetching images:', error);
        alert('Fehler beim Laden der Bilder');
      })
      .finally(() => {
        this.state.isLoading = false;
      });
  },

  fetchImageItemsForPagination() {
    const { type, page, search } = this.state;

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    return fetch(`/ckeditor/assets?${new URLSearchParams({ type, page, search })}`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': csrfToken
      }
    })
      .then(response => response.json())
      .then(data => {
        this.state.total_pages = data.total_pages;

        this.updatePagination();
        this.updateUploadingState()
      })
  },

  handleUploadError(tempItemId, errorMessage) {
    alert(errorMessage);
    // Refresh the page to get updated server state
    this.fetchImageItems();
  },

  uploadNewImage(formData, tempItemId) {
    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    // Track uploading state for dialog
    this.incrementUploadingCount();

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
          this.handleUploadError(tempItemId, resp.error.message);
        } else {
          // Refresh the page to show the newly uploaded image
          this.fetchImageItems();
        }
      })
      .catch(error => {
        console.error('Error uploading image:', error);
        this.handleUploadError(tempItemId, 'Fehler beim Hochladen des Bildes');
      })
      .finally(() => {
        this.decrementUploadingCount();

        if (this.contentBlockId && this.contentBlockWrapper) {
          ProjektStudio.ContentBlockSimpleEdit.ImageEdit.decrementImageLoadingCount(this.contentBlockId);

          const loadingState = ProjektStudio.ContentBlockSimpleEdit.ImageEdit.contentBlockImageLoadingState;
          if (loadingState[this.contentBlockId] <= 0) {
            ProjektStudio.ContentBlockSimpleEdit.toggleLockSaveCancel(this.contentBlockWrapper, false);
          }
        }
      });
  },




  handlePaginationClick(e) {
    const pageNumber = parseInt(e.currentTarget.dataset.page);

    this.navigateToPage(pageNumber)
  },

  handleKaminariPaginationClick(e) {
    e.preventDefault();
    e.stopImmediatePropagation()

    const url = new URL(e.currentTarget.href);
    const pageNumber = parseInt(url.searchParams.get('page')) || 1;

    this.navigateToPage(pageNumber);
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
          // Update selected image with new data
          this.state.selectedImage = {
            id: data.id,
            title: data.title,
            alt_text: data.alt_text
          };
          this.closeEditModal();
          // Refresh to show updated data
          this.fetchImageItems();
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
          this.state.selectedImage = null;
          this.updateEditButtonVisibility();
          this.closeEditModal();
          // Refresh to show updated data
          this.fetchImageItems();
        }
      })
      .catch(error => {
        console.error('Error deleting image:', error);
        alert('Fehler beim Löschen des Bildes');
      });
  }
}
