ProjektStudio.ContentBlock.SimpleEditMode.ImageGalleryDialog = {
  state: {
    type: 'picture',
    page: 1,
    search: '',
    selectedImage: null,
    isLoading: false,
    uploadingCount: 0,
    removedItemsStack: []
  },
  onSelectCallback: null,
  contentBlockId: null,
  contentBlockWrapper: null,
  paginationSize: 15,

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

    $document.on("click", ".js-file-upload-manager-dialog-close", this.closeDialog.bind(this));
    $document.on("close", ".js-file-upload-manager-dialog", this.handleDialogClosed.bind(this));
    $document.on("cancel", ".js-file-upload-manager-dialog", this.handleDialogCancel.bind(this));

    $document.on("input", ".js-file-upload-manager-search", this.handleSearchInputType.bind(this));
    $document.on("keydown", ".js-file-upload-manager-search", this.handleSearchKeydown.bind(this));
    $document.on("click", ".js-file-upload-manager-search-clear", this.clearSearch.bind(this));

    // $document.on("click", ".js-file-upload-manager-filter", this.handleFilterClick.bind(this));
    $document.on("click", ".js-file-upload-manager-upload", this.handleUploadButtonClick.bind(this));
    $document.on("change", ".js-file-upload-manager-file-input", this.handleFileInputChange.bind(this));

    $document.on("click", ".js-file-upload-manager-edit", this.openEditModal.bind(this));
    $document.on("click", ".js-file-upload-manager-edit-close", this.closeEditModal.bind(this));
    $document.on("click", ".js-file-upload-manager-update", this.updateImage.bind(this));
    $document.on("click", ".js-file-upload-manager-delete", this.deleteImage.bind(this));

    $document.on("click", ".js-file-upload-manager-select", this.handleImageSelected.bind(this));
    $document.on("click", ".file-upload-manager-dialog--item", this.handleItemClick.bind(this));
    $document.on("click", ".pagination a", this.handleKaminariPaginationClick.bind(this));
  },

  getDialogElement() {
    return document.querySelector(".js-file-upload-manager-dialog");
  },

  async openDialog(onSelectCallback, contentBlockId = null, contentBlockWrapper = null) {
    this.onSelectCallback = onSelectCallback;
    this.contentBlockId = contentBlockId;
    this.contentBlockWrapper = contentBlockWrapper;

    this.state = {
      type: 'picture',
      page: 1,
      search: '',
      selectedImage: null,
      isLoading: false,
      uploadingCount: 0,
      removedItemsStack: []
    };

    const dialog = this.getDialogElement();
    if (dialog && !dialog.open) {
      dialog.showModal();
    }
    if (dialog) {
      dialog.classList.add("-opened");
    }
    $(".js-file-upload-manager-search").val("")

    this.updateEditButtonVisibility();
    this.updateSelectButtonState();
    this.fetchImageItems();
  },

  closeDialog(_e) {
    this.requestDialogClose();
  },

  requestDialogClose() {
    const dialog = this.getDialogElement();
    if (dialog && dialog.open) {
      dialog.close();
    } else {
      this.handleDialogClosed();
    }
  },

  handleDialogCancel(e) {
    e.preventDefault();
    this.requestDialogClose();
  },

  handleDialogClosed() {
    const dialog = this.getDialogElement();
    if (dialog) {
      dialog.classList.remove("-opened");
    }
    $(".js-file-upload-manager-grid, .js-file-upload-manager-pagination").empty()

    this.state.selectedImage = null;
    this.onSelectCallback = null;
    this.contentBlockId = null;
    this.contentBlockWrapper = null;

    this.updateSelectButtonState();
    this.resetSelectedImageItems()
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
    const searchInput = document.querySelector('.js-file-upload-manager-search');
    const pagination = document.querySelector('.js-file-upload-manager-pagination');

    searchInput.disabled = isUploading;

    if (pagination) {
      pagination.classList.toggle('-disabled', isUploading);
      $(".js-file-upload-manager-page-btn").prop("disabled", isUploading)
      $(`.js-file-upload-manager-page-btn[data-page=${this.state.page}]`).prop("disabled", true)
    }
  },

  handleSearchInputType(e) {
    this.state.search = e.target.value;

    this.debouncedSearch();
  },

  handleSearchKeydown(e) {
    if (e.key === 'Enter') {
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
    const searchInput = document.querySelector(".js-file-upload-manager-search");
    if (searchInput) {
      searchInput.value = '';
    }
    this.state.search = '';
    this.performSearch();
  },

  // handleFilterClick(e) {
  //   const type = e.currentTarget.dataset.type;

  //   if (type !== this.state.type) {
  //     this.state.type = type;
  //     this.state.page = 1;

  //     document.querySelectorAll(".js-file-upload-manager-filter").forEach(btn => {
  //       btn.classList.remove("active");
  //     });
  //     e.currentTarget.classList.add("active");

  //     this.fetchImageItems();
  //   }
  // },

  async navigateToPage(pageNumber) {
    if (pageNumber && pageNumber !== this.state.page) {
      $(".js-file-upload-manager-page-btn.-active").removeClass("-active").prop("disabled", false)
      $(`.js-file-upload-manager-page-btn[data-page=${pageNumber}]`).addClass("-active").prop("disabled", true)

      this.state.page = pageNumber;
      await this.fetchImageItems();
    }
  },

  handleUploadButtonClick(_e) {
    const fileInput = document.querySelector('.js-file-upload-manager-file-input');
    fileInput.value = '';

    fileInput.click();
  },

  async handleFileInputChange(event) {
    await this.navigateToPage(1);

    const files = event.target.files;

    if (files && files.length > 0) {
      const file = files[0];

      this.genImageInMemoryPreview(file, (previewUrl) => {
        const uploadingItem = this.buildImageUploadingItem(file, previewUrl)

        this.renderUploadingItem(uploadingItem);
        this.uploadNewImage(file, uploadingItem.id);
      })
    }
  },

  genImageInMemoryPreview(file, callback) {
    const reader = new FileReader();
    reader.onload = (e) => {
      callback(e.target.result)
    };

    reader.readAsDataURL(file);
  },

  removeLastItemIfNeeded() {
    const grid = document.querySelector('.js-file-upload-manager-grid');
    const items = grid.querySelectorAll('.file-upload-manager-dialog--item');

    if (items.length >= this.paginationSize) {
      const lastItem = items[items.length - 1];
      this.state.removedItemsStack.push(lastItem);
      lastItem.remove();
    }
  },

  restoreRemovedItem() {
    if (this.state.removedItemsStack.length > 0) {
      const removedItem = this.state.removedItemsStack.pop();

      document
        .querySelector('.js-file-upload-manager-grid')
        .appendChild(removedItem);
    }
  },

  buildImageUploadingItem(file, inMemoryUrl) {
    return {
      id: `temp-${Date.now()}`,
      in_memory_preview_url: inMemoryUrl,
      title: file.name,
      data_file_name: file.name,
      data_content_type: file.type,
    };
  },

  renderUploadingItem(tempImageData) {
    const template = document.getElementById('file-upload-manager-uploading-template');
    const documentFramgment = template.content.cloneNode(true);
    const itemElement = documentFramgment.querySelector('.file-upload-manager-dialog--item');

    this.updateImageItem(itemElement, tempImageData)

    const grid = document.querySelector('.js-file-upload-manager-grid');
    grid.insertBefore(documentFramgment, grid.firstChild);

    this.removeLastItemIfNeeded();
  },

  updateUploadItemWithData(uploadItemId, imageData) {
    const uploadItemElement = document.querySelector(`[data-id="${uploadItemId}"]`);
    const image = new Image()
    image.src = imageData.gallery_thumb_url

    image.onload = () => {
      this.updateImageItem(uploadItemElement, imageData)
      uploadItemElement.classList.remove('-uploading');
      uploadItemElement.querySelector(".file-upload-manager-dialog--item-uploading").remove()
    }
  },

  updateImageItem(imageItem, imageData) {
    const $imageItem = $(imageItem)

    imageItem.dataset.id = imageData.id;
    imageItem.dataset.url = imageData.url || '';
    imageItem.dataset.customThumbUrl = imageData.custom_thumb_url

    if (imageData.gallery_thumb_url) {
      $imageItem.find('.js-file-upload-manager-dialog_item-image').attr('src', imageData.gallery_thumb_url)
    }

    if (imageData.in_memory_preview_url) {
      imageItem
        .querySelector('.file-upload-manager-dialog--item-preview')
        .style.backgroundImage = `url('${imageData.in_memory_preview_url}')`;
    }

    $imageItem
      .find('.file-upload-manager-dialog--item-title')
      .text(imageData.title)
      .attr("title", imageData.title)

    $imageItem
      .find('.file-upload-manager-dialog--item-alt')
      .text(imageData.alt_text || '')
  },

  handleItemClick(e) {
    const item = e.currentTarget;

    if (this.state.selectedImage === item) {
      this.state.selectedImage = null;
    } else {
      this.state.selectedImage = item;
    }

    this.resetSelectedImageItems()
    item.classList.toggle("-selected", this.state.selectedImage === item)

    this.updateEditButtonVisibility();
    this.updateSelectButtonState();
  },

  resetSelectedImageItems() {
    $(".file-upload-manager-dialog--item.-selected").removeClass("-selected")
  },

  handleImageSelected() {
    if (!this.state.selectedImage) return

    if (this.onSelectCallback && typeof this.onSelectCallback === 'function') {
      const selectedImage = this.state.selectedImage;

      const imageData = {
        id: selectedImage.dataset.id,
        title: selectedImage.querySelector('.file-upload-manager-dialog--item-title').textContent || '',
        alt_text: selectedImage.querySelector('.file-upload-manager-dialog--item-alt').textContent || '',
        description: selectedImage.dataset.description || '',
        url: selectedImage.dataset.url || '',
        gallery_thumb_url: selectedImage.querySelector("img").src,
        custom_thumb_url: selectedImage.dataset.customThumbUrl
      };
      this.onSelectCallback(imageData);
    }

    this.closeDialog();
  },

  async fetchImageItems() {
    this.state.isLoading = true;
    this.showLoadingOverlay();

    try {
      const response = await this.fetchImageData();
      const html = await response.text();
      const dialogBody = document.querySelector('.js-file-upload-manager-dialog--body');
      dialogBody.innerHTML = html;
    } catch (error) {
      console.error('Error fetching images:', error);
      alert('Fehler beim Laden der Bilder');
    } finally {
      this.state.isLoading = false;
      this.hideLoadingOverlay();
    }
  },

  showLoadingOverlay() {
    const overlay = document.querySelector('.js-file-upload-manager-loading-overlay');
    overlay.style.display = 'flex';
  },

  hideLoadingOverlay() {
    const overlay = document.querySelector('.js-file-upload-manager-loading-overlay');
    overlay.style.display = 'none';
  },

  async fetchImageData(params = {}) {
    const { type, page, search } = this.state;

    return await fetch(`/ckeditor/assets?${new URLSearchParams({ type, page, search, ...params })}`, {
      method: 'GET',
      headers: {
        'Accept': 'text/html',
        'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content'),
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      }
    });
  },

  handleUploadError(uploadItemId, errorMessage) {
    alert(errorMessage);

    const uploadingItem = document.querySelector(`[data-id="${uploadItemId}"]`);
    uploadingItem.remove();

    this.restoreRemovedItem();
  },

  async uploadNewImage(file, uploadItemId) {
    const formData = new FormData();
    formData.append('upload', file);

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    this.incrementUploadingCount();

    if (this.contentBlockId && this.contentBlockWrapper) {
      ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.incrementImageLoadingCount(this.contentBlockId);
      ProjektStudio.ContentBlock.SimpleEditMode.toggleLockSaveCancel(this.contentBlockWrapper, true);
    }

    fetch('/ckeditor/pictures', {
      method: 'POST',
      headers: {
        'X-CSRF-TOKEN': csrfToken,
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
      body: formData
    })
      .then(response => response.json())
      .then(resp => {
        if (resp.error) {
          this.handleUploadError(uploadItemId, resp.error.message);
        } else {
          this.updateUploadItemWithData(uploadItemId, resp);
          this.fetchAndUpdatePagination()
        }
      })
      .catch(error => {
        console.error('Error uploading image:', error);
        this.handleUploadError(uploadItemId, 'Fehler beim Hochladen des Bildes');
      })
      .finally(() => {
        this.decrementUploadingCount();

        if (this.contentBlockId && this.contentBlockWrapper) {
          ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.decrementImageLoadingCount(this.contentBlockId);

          const loadingState = ProjektStudio.ContentBlock.SimpleEditMode.ImageEdit.contentBlockImageLoadingState;
          if (loadingState[this.contentBlockId] <= 0) {
            ProjektStudio.ContentBlock.SimpleEditMode.toggleLockSaveCancel(this.contentBlockWrapper, false);
          }
        }
      });
  },

  async fetchAndUpdatePagination() {
    const response = await this.fetchImageData({ pagination_only: "true"});
    const html = await response.text();
    $(".js-file-upload-manager-pagination").replaceWith(html);
  },

  async handleKaminariPaginationClick(e) {
    e.preventDefault();
    e.stopImmediatePropagation()

    const url = new URL(e.currentTarget.href);
    const pageNumber = parseInt(url.searchParams.get('page')) || 1;

    await this.navigateToPage(pageNumber);
  },

  updateEditButtonVisibility() {
    const editBtn = document.querySelector(".js-file-upload-manager-edit");
    if (editBtn) {
      editBtn.style.display = this.state.selectedImage ? 'block' : 'none';
    }
  },

  updateSelectButtonState() {
    const selectBtn = document.querySelector(".js-file-upload-manager-select");
    if (selectBtn) {
      const hasSelection = this.state.selectedImage !== null;
      const isChosenUploading = this.state.selectedImage && this.state.selectedImage.classList.contains('-uploading');

      selectBtn.disabled = !hasSelection || isChosenUploading;
    }
  },

  openEditModal(e) {
    if (!this.state.selectedImage) return;

    const editModal = document.querySelector(".js-file-upload-manager-edit-modal");
    editModal.classList.add("-opened");

    const titleInput = editModal.querySelector(".js-file-upload-manager-edit-title");
    const descInput = editModal.querySelector(".js-file-upload-manager-edit-description");
    const altInput = editModal.querySelector(".js-file-upload-manager-edit-alt");

    titleInput.value = (this.state.selectedImage.querySelector('.file-upload-manager-dialog--item-title').textContent || '').trim();
    descInput.value = (this.state.selectedImage.dataset.description || '').trim();
    altInput.value = (this.state.selectedImage.querySelector('.file-upload-manager-dialog--item-alt').textContent || '').trim();
  },

  closeEditModal(e) {
    $(".js-file-upload-manager-edit-modal").removeClass("-opened")
  },

  async updateImage(e) {
    if (!this.state.selectedImage) return;

    const modal = document.querySelector(".js-file-upload-manager-edit-modal");
    const titleInput = modal.querySelector(".js-file-upload-manager-edit-title");
    const descInput = modal.querySelector(".js-file-upload-manager-edit-description");
    const altInput = modal.querySelector(".js-file-upload-manager-edit-alt");

    const formData = new FormData();
    const type = this.state.type
    formData.append(`${type}[title]`, titleInput.value);
    formData.append(`${type}[description]`, descInput.value);
    formData.append(`${type}[alt_text]`, altInput.value);

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    try {
      const response = await fetch(`/ckeditor/pictures/${this.state.selectedImage.dataset.id}`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-TOKEN': csrfToken,
          'X-Embedded-Frame': ProjektStudio.isEmbedded
        },
        body: formData
      });

      const data = await response.json();

      if (data.id) {
        this.closeEditModal();
        await this.fetchImageItems();
      }
    } catch (error) {
      console.error('Error updating image:', error);
      alert('Fehler beim Aktualisieren des Bildes');
    }
  },

  async deleteImage(e) {
    if (!this.state.selectedImage) return;

    if (!confirm('Möchten Sie dieses Bild wirklich löschen?')) {
      return;
    }

    const chosenId = this.state.selectedImage.dataset.id;
    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    try {
      const response = await fetch(`/ckeditor/pictures/${chosenId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-TOKEN': csrfToken,
          'X-Embedded-Frame': ProjektStudio.isEmbedded
        }
      });

      const data = await response.json();

      if (data.status && data.status === 'no_content') {
        this.state.selectedImage = null;
        this.updateEditButtonVisibility();
        this.closeEditModal();
        await this.fetchImageItems();
      }
    } catch (error) {
      console.error('Error deleting image:', error);
      alert('Fehler beim Löschen des Bildes');
    }
  }
}
