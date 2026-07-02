App.Studio.ContentBlocks.SimpleEditMode.FileManagerDialog = {
  state: {
    type: 'picture',
    page: 1,
    filters: {},
    selectedImage: null,
    isLoading: false,
    uploadingCount: 0,
    removedItemsStack: []
  },
  activeDialog: null,
  onSelectCallback: null,
  onCancelCallback: null,
  selectionConfirmed: false,
  contentBlockId: null,
  contentBlockWrapper: null,
  paginationSize: 15,
  fileAccept: {
    picture: 'image/*',
    document: ''
  },
  uploadEndpoints: {
    picture: '/file_manager/images',
    document: '/file_manager/documents'
  },
  listEndpoints: {
    picture: '/file_manager/images',
    document: '/file_manager/documents'
  },
  infoEndpoints: {
    picture: '/file_manager/images',
    document: '/file_manager/documents'
  },
  fileTypeIcons: {
    'application/pdf': 'fa-file-pdf',
    'application/msword': 'fa-file-word',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': 'fa-file-word',
    'application/vnd.ms-excel': 'fa-file-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'fa-file-excel',
    'application/vnd.ms-powerpoint': 'fa-file-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation': 'fa-file-powerpoint',
    'application/zip': 'fa-file-zipper',
    'application/x-rar-compressed': 'fa-file-zipper',
    'application/x-7z-compressed': 'fa-file-zipper',
    'application/json': 'fa-file-code',
    'application/xml': 'fa-file-code',
    'application/rtf': 'fa-file-lines',
    'text/rtf': 'fa-file-lines',
    'text/csv': 'fa-file-csv',
    'application/vnd.oasis.opendocument.text': 'fa-file-word',
    'application/vnd.oasis.opendocument.spreadsheet': 'fa-file-excel'
  },

  getFileTypeIcon(contentType) {
    if (!contentType) return 'fa-file';
    if (this.fileTypeIcons[contentType]) return this.fileTypeIcons[contentType];
    if (contentType.startsWith('image/')) return 'fa-file-image';
    if (contentType.startsWith('text/')) return 'fa-file-lines';
    if (contentType.startsWith('video/')) return 'fa-file-video';
    if (contentType.startsWith('audio/')) return 'fa-file-audio';

    return 'fa-file';
  },

  currentProjektId() {
    if (typeof App.Studio.Projekt === "undefined") return null;
    if (typeof App.Studio.Projekt.isProjektPage !== "function") return null;
    if (!App.Studio.Projekt.isProjektPage()) return null;

    return App.Studio.Projekt.getCurrentProjektId();
  },

  emailOrigin() {
    const editor = document.querySelector(".js-newsletter-content-block-editor");

    if (!editor) return null;

    return editor.dataset.emailOrigin || window.location.origin;
  },

  resolveFileUrl(url) {
    if (!url) return "";

    const emailOrigin = this.emailOrigin();

    if (!emailOrigin) return url;

    return new URL(url, emailOrigin).href;
  },

  initialize() {
    this.initEventListeners()
    this.initDebouncedSearch()
  },

  initDebouncedSearch() {
    this.debouncedSearchChanged = App.Studio.utils.debounce(() => {
      this.refetchAfterFilterChange();
    }, 200);
  },

  initEventListeners() {
    const $document = $(document);

    $document.on("click", ".js-file-upload-manager-dialog-close", this.closeDialog.bind(this));
    $document.on("close", ".js-file-upload-manager-dialog", this.handleDialogClosed.bind(this));
    $document.on("cancel", ".js-file-upload-manager-dialog", this.handleDialogCancel.bind(this));

    $document.on("input", ".js-fm-filter-search", this.handleSearchChanged.bind(this));
    $document.on("change", ".js-fm-filter-extension, .js-fm-filter-size-min, .js-fm-filter-size-max, .js-fm-filter-created-from, .js-fm-filter-created-to, .js-fm-filter-updated-from, .js-fm-filter-updated-to", this.handleFilterChanged.bind(this));
    $document.on("change", ".js-fm-filter-sort", this.handleSortChanged.bind(this));
    $document.on("click", ".js-fm-filter-reset", this.handleResetClicked.bind(this));

    $document.on("click", ".js-file-upload-manager-upload", this.handleUploadButtonClick.bind(this));
    $document.on("click", ".js-file-upload-manager-upload-crop", this.handleUploadWithCropButtonClick.bind(this));
    $document.on("change", ".js-file-upload-manager-file-input", this.handleFileInputChange.bind(this));

    $document.on("click", ".js-file-upload-manager-info", this.openInfoModal.bind(this));
    $document.on("click", ".js-file-upload-manager-info-close", this.closeInfoModal.bind(this));

    $document.on("click", ".js-file-upload-manager-fullsize", this.openFullsizePreview.bind(this));
    $document.on("click", ".js-file-upload-manager-fullsize-close", this.closeFullsizePreview.bind(this));

    $document.on("click", ".js-file-upload-manager-edit", this.openEditModal.bind(this));
    $document.on("click", ".js-file-upload-manager-edit-close", this.closeEditModal.bind(this));
    $document.on("click", ".js-file-upload-manager-update", this.updateImage.bind(this));
    $document.on("click", ".js-file-upload-manager-delete", this.deleteImage.bind(this));

    $document.on("click", ".js-file-upload-manager-select", this.handleImageSelected.bind(this));
    $document.on("click", ".file-upload-manager-dialog--item", this.handleItemClick.bind(this));
    $document.on("click", ".js-file-upload-manager-pagination .pagination a", this.handleKaminariPaginationClick.bind(this));
  },

  getDialogElement(type) {
    return document.querySelector(`.js-file-upload-manager-dialog[data-type="${type}"]`);
  },

  q(sel) {
    return this.activeDialog.querySelector(sel);
  },

  $q(sel) {
    return $(this.activeDialog).find(sel);
  },

  openForImages(onSelectCallback, contentBlockId = null, contentBlockWrapper = null, onCancelCallback = null) {
    this.openDialog('picture', onSelectCallback, contentBlockId, contentBlockWrapper, onCancelCallback);
  },

  openForDocuments(onSelectCallback, contentBlockId = null, contentBlockWrapper = null, onCancelCallback = null) {
    this.openDialog('document', onSelectCallback, contentBlockId, contentBlockWrapper, onCancelCallback);
  },

  openDialog(type, onSelectCallback, contentBlockId, contentBlockWrapper, onCancelCallback) {
    this.onSelectCallback = onSelectCallback;
    this.onCancelCallback = onCancelCallback;
    this.selectionConfirmed = false;

    this.contentBlockId = contentBlockId;
    this.contentBlockWrapper = contentBlockWrapper;

    this.state = {
      type: type,
      page: 1,
      filters: {},
      selectedImage: null,
      isLoading: false,
      uploadingCount: 0,
      removedItemsStack: [],
      cropOnUpload: false
    };

    this.activeDialog = this.getDialogElement(type);

    if (this.activeDialog && !this.activeDialog.open) {
      this.activeDialog.showModal();
    }

    this.resetFilterForm();

    this.updateEditButtonVisibility();
    this.updateSelectButtonState();
    this.fetchImageItems();
  },

  resetFilterForm() {
    if (!this.activeDialog) return;

    const filterBar = this.activeDialog.querySelector(".js-fm-filter-bar");
    if (!filterBar) return;

    const inputs = filterBar.querySelectorAll("input, select");
    inputs.forEach((input) => {
      if (input.tagName === "SELECT") {
        input.selectedIndex = 0;
      } else {
        input.value = "";
      }
    });

    this.state.filters = window.FilesFilterSerializer.serializeForm(filterBar);
  },

  readFilterParams() {
    if (!this.activeDialog) return {};

    const filterBar = this.activeDialog.querySelector(".js-fm-filter-bar");
    if (!filterBar) return {};

    return window.FilesFilterSerializer.serializeForm(filterBar);
  },

  refetchAfterFilterChange() {
    this.state.filters = this.readFilterParams();
    this.state.page = 1;
    this.fetchImageItems();
  },

  handleSearchChanged(_e) {
    this.debouncedSearchChanged();
  },

  handleFilterChanged(_e) {
    this.refetchAfterFilterChange();
  },

  handleSortChanged(_e) {
    this.refetchAfterFilterChange();
  },

  handleResetClicked(e) {
    e.preventDefault();
    this.resetFilterForm();
    this.state.page = 1;
    this.fetchImageItems();
  },

  closeDialog(_e) {
    this.requestDialogClose();
  },

  requestDialogClose() {
    if (this.activeDialog && this.activeDialog.open) {
      this.activeDialog.close();
    } else {
      this.handleDialogClosed();
    }
  },

  handleDialogCancel(e) {
    e.preventDefault();
    this.requestDialogClose();
  },

  handleDialogClosed() {
    if (this.activeDialog) {
      this.$q(".js-file-upload-manager-grid, .js-file-upload-manager-pagination").empty();
    }

    if (!this.selectionConfirmed && this.onCancelCallback) {
      this.onCancelCallback();
    }

    this.state.selectedImage = null;
    this.onSelectCallback = null;
    this.onCancelCallback = null;
    this.selectionConfirmed = false;
    this.contentBlockId = null;
    this.contentBlockWrapper = null;

    this.updateSelectButtonState();
    this.resetSelectedImageItems();
    this.activeDialog = null;
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
    const searchInput = this.q('.js-fm-filter-search');
    const pagination = this.q('.js-file-upload-manager-pagination');

    if (searchInput) {
      searchInput.disabled = isUploading;
    }

    if (pagination) {
      pagination.classList.toggle('-disabled', isUploading);
      this.$q(".js-file-upload-manager-page-btn").prop("disabled", isUploading);
      this.$q(`.js-file-upload-manager-page-btn[data-page=${this.state.page}]`).prop("disabled", true);
    }
  },

  async navigateToPage(pageNumber) {
    if (pageNumber && pageNumber !== this.state.page) {
      this.$q(".js-file-upload-manager-page-btn.-active").removeClass("-active").prop("disabled", false);
      this.$q(`.js-file-upload-manager-page-btn[data-page=${pageNumber}]`).addClass("-active").prop("disabled", true);

      this.state.page = pageNumber;
      await this.fetchImageItems();
    }
  },

  handleUploadButtonClick(_e) {
    this.state.cropOnUpload = false;
    this.openFilePicker();
  },

  handleUploadWithCropButtonClick(_e) {
    this.state.cropOnUpload = true;
    this.openFilePicker();
  },

  openFilePicker() {
    const fileInput = this.q('.js-file-upload-manager-file-input');
    fileInput.value = '';
    fileInput.accept = this.fileAccept[this.state.type];
    fileInput.click();
  },

  async handleFileInputChange(event) {
    await this.navigateToPage(1);
    if (this._fetchPromise) await this._fetchPromise;

    const files = event.target.files;
    if (!files || files.length === 0) return;

    const file = files[0];
    const cropRequested = this.state.cropOnUpload;
    this.state.cropOnUpload = false;

    if (cropRequested && this.canCropImage(file)) {
      this.openCropThenUpload(file);
      return;
    }

    this.startUpload(file);
  },

  canCropImage(file) {
    return !!(window.App && App.ImageCropper) &&
      App.ImageCropper.isCroppableImage(file);
  },

  openCropThenUpload(file) {
    App.ImageCropper.open(file, {
      onConfirm: (croppedFile) => this.startUpload(croppedFile)
    });
  },

  startUpload(file) {
    if (file.type.startsWith('image/')) {
      this.genImageInMemoryPreview(file, (previewUrl) => {
        const uploadingItem = this.buildImageUploadingItem(file, previewUrl);
        this.renderUploadingItem(uploadingItem);
        this.uploadNewFile(file, uploadingItem.id);
      });
    } else {
      const uploadingItem = this.buildImageUploadingItem(file, null);
      this.renderUploadingItem(uploadingItem);
      this.uploadNewFile(file, uploadingItem.id);
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
    const grid = this.q('.js-file-upload-manager-grid');
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

      this.q('.js-file-upload-manager-grid').appendChild(removedItem);
    }
  },

  buildImageUploadingItem(file, inMemoryUrl) {
    return {
      id: `temp-${Date.now()}`,
      in_memory_preview_url: inMemoryUrl,
      title: file.name,
      data_file_name: file.name,
      data_content_type: file.type,
      file_size: file.size,
    };
  },

  renderUploadingItem(tempImageData) {
    const template = this.q('.js-file-upload-manager-uploading-template');
    const documentFramgment = template.content.cloneNode(true);
    const itemElement = documentFramgment.querySelector('.file-upload-manager-dialog--item');

    this.updateImageItem(itemElement, tempImageData);
    itemElement.dataset.contentType = tempImageData.data_content_type;

    const isImage = tempImageData.data_content_type
      && tempImageData.data_content_type.startsWith('image/');

    if (!isImage) {
      const img = itemElement.querySelector('.js-file-upload-manager-dialog_item-image');
      if (img) img.style.display = 'none';

      const icon = itemElement.querySelector('.js-file-upload-manager-dialog_item-icon');
      if (icon) {
        icon.classList.add(this.getFileTypeIcon(tempImageData.data_content_type));
        icon.style.display = '';
      }
    }

    const grid = this.q('.js-file-upload-manager-grid');
    if (!grid) return

    grid.insertBefore(documentFramgment, grid.firstChild);

    this.removeLastItemIfNeeded();
  },

  updateUploadItemWithData(uploadItemId, imageData) {
    const uploadItemElement = this.q(`[data-id="${uploadItemId}"]`);

    if (!uploadItemElement) {
      this.fetchImageItems();
      return
    }

    const finalize = () => {
      this.updateImageItem(uploadItemElement, imageData);
      uploadItemElement.classList.remove('-uploading');
      uploadItemElement.querySelector(".file-upload-manager-dialog--item-uploading").remove();
    };

    if (imageData.gallery_thumb_url) {
      const img = uploadItemElement.querySelector('.js-file-upload-manager-dialog_item-image');
      const icon = uploadItemElement.querySelector('.js-file-upload-manager-dialog_item-icon');

      if (img) img.style.display = '';
      if (icon) icon.style.display = 'none';

      const image = new Image();
      image.src = imageData.gallery_thumb_url;
      image.onload = finalize;
    } else {
      finalize();
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

    var $itemTitle = $imageItem.find('.file-upload-manager-dialog--item-title')
    $itemTitle
      .text(imageData.title)
      .attr("title", imageData.title)

    $imageItem
      .find('.file-upload-manager-dialog--item-alt')
      .text(imageData.alt_text || '')

    var $sizeBadge = $imageItem.find('.js-file-manager-badge-size')
    if (imageData.file_size) {
      $sizeBadge.text(this.formatFileSize(imageData.file_size)).show()
    }

    var $dimBadge = $imageItem.find('.js-file-manager-badge-dimensions')
    if (imageData.dimensions && imageData.dimensions.width && imageData.dimensions.height) {
      $dimBadge.text(imageData.dimensions.width + ' × ' + imageData.dimensions.height).show()
    }
  },

  formatFileSize(bytes) {
    if (!bytes) return ''
    if (bytes < 1024) return bytes + ' B'
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB'
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB'
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
    if (this.activeDialog) {
      this.$q(".file-upload-manager-dialog--item.-selected").removeClass("-selected");
    }
  },

  handleImageSelected() {
    if (!this.state.selectedImage) return

    if (this.onSelectCallback && typeof this.onSelectCallback === 'function') {
      this.selectionConfirmed = true;
      const selectedImage = this.state.selectedImage;
      const imgEl = selectedImage.querySelector('img');

      const imageData = {
        id: selectedImage.dataset.id,
        title: selectedImage.querySelector('.file-upload-manager-dialog--item-title').textContent || '',
        alt_text: selectedImage.querySelector('.file-upload-manager-dialog--item-alt').textContent || '',
        description: selectedImage.dataset.description || '',
        url: this.resolveFileUrl(selectedImage.dataset.url),
        content_type: selectedImage.dataset.contentType || '',
        gallery_thumb_url: imgEl ? imgEl.src : '',
        custom_thumb_url: this.resolveFileUrl(selectedImage.dataset.customThumbUrl)
      };
      this.onSelectCallback(imageData);
    }

    this.closeDialog();
  },

  async fetchImageItems() {
    this.state.isLoading = true;
    this.showLoadingOverlay();

    this._fetchPromise = (async () => {
      try {
        const response = await this.fetchImageData();
        const html = await response.text();
        const dialogBody = this.q('.js-file-upload-manager-dialog--body');
        dialogBody.innerHTML = html;
      } catch (error) {
        console.error('Error fetching files:', error);
        alert('Fehler beim Laden der Dateien');
      } finally {
        this.state.isLoading = false;
        this.hideLoadingOverlay();
      }
    })();

    await this._fetchPromise;
  },

  showLoadingOverlay() {
    const overlay = this.q('.js-file-upload-manager-loading-overlay');

    if (overlay) {
      overlay.style.display = 'flex';
    }
  },

  hideLoadingOverlay() {
    const overlay = this.q('.js-file-upload-manager-loading-overlay');

    if (overlay) {
      overlay.style.display = 'none';
    }
  },

  async fetchImageData(extraParams = {}) {
    const { type, page, filters } = this.state;
    const filterParams = Object.assign({}, filters, { type, page });
    const projektId = this.currentProjektId();

    if (projektId) {
      filterParams.projekt_id = projektId;
    }

    const baseUrl = this.listEndpoints[type] || this.listEndpoints.picture;
    let url = window.FilesFilterSerializer.urlForParams(baseUrl, filterParams);

    Object.keys(extraParams).forEach((key) => {
      const separator = url.indexOf("?") >= 0 ? "&" : "?";
      url = `${url}${separator}${encodeURIComponent(key)}=${encodeURIComponent(extraParams[key])}`;
    });

    return await fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'text/html',
        'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
      }
    });
  },

  handleUploadError(uploadItemId, errorMessage) {
    alert(errorMessage);

    const uploadingItem = this.q(`[data-id="${uploadItemId}"]`);
    uploadingItem.remove();

    this.restoreRemovedItem();
  },

  async uploadNewFile(file, uploadItemId) {
    const formData = new FormData();
    formData.append('upload', file);

    const projektId = this.currentProjektId();
    if (projektId) {
      formData.append('projekt_id', projektId);
    }

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    this.incrementUploadingCount();

    if (this.contentBlockId && this.contentBlockWrapper) {
      App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.incrementImageLoadingCount(this.contentBlockId);
      App.Studio.ContentBlocks.SimpleEditMode.toggleLockSaveCancel(this.contentBlockWrapper, true);
    }

    fetch(this.uploadEndpoints[this.state.type], {
      method: 'POST',
      headers: {
        'X-CSRF-TOKEN': csrfToken
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
        console.error('Error uploading file:', error);
        this.handleUploadError(uploadItemId, 'Fehler beim Hochladen der Datei');
      })
      .finally(() => {
        this.decrementUploadingCount();

        if (this.contentBlockId && this.contentBlockWrapper) {
          App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.decrementImageLoadingCount(this.contentBlockId);

          const loadingState = App.Studio.ContentBlocks.SimpleEditMode.ImageEdit.contentBlockImageLoadingState;
          if (loadingState[this.contentBlockId] <= 0) {
            App.Studio.ContentBlocks.SimpleEditMode.toggleLockSaveCancel(this.contentBlockWrapper, false);
          }
        }
      });
  },

  async fetchAndUpdatePagination() {
    const response = await this.fetchImageData({ pagination_only: "true"});
    const html = await response.text();
    this.$q(".js-file-upload-manager-pagination").replaceWith(html);
  },

  async handleKaminariPaginationClick(e) {
    e.preventDefault();
    e.stopImmediatePropagation()

    const url = new URL(e.currentTarget.href);
    const pageNumber = parseInt(url.searchParams.get('page')) || 1;

    await this.navigateToPage(pageNumber);
  },

  updateEditButtonVisibility() {
    const hasSelection = !!this.state.selectedImage;
    const displayValue = hasSelection ? 'block' : 'none';

    const editBtn = this.q(".js-file-upload-manager-edit");
    if (editBtn) editBtn.style.display = displayValue;

    const infoBtn = this.q(".js-file-upload-manager-info");
    if (infoBtn) infoBtn.style.display = displayValue;

    const fullsizeBtn = this.q(".js-file-upload-manager-fullsize");
    if (fullsizeBtn) {
      const hasFullsizeUrl = hasSelection && !!this.state.selectedImage.dataset.url;
      fullsizeBtn.style.display = hasFullsizeUrl ? 'block' : 'none';
    }
  },

  updateSelectButtonState() {
    const selectBtn = this.q(".js-file-upload-manager-select");
    if (selectBtn) {
      const hasSelection = this.state.selectedImage !== null;
      const isChosenUploading = this.state.selectedImage && this.state.selectedImage.classList.contains('-uploading');

      selectBtn.disabled = !hasSelection || isChosenUploading;
    }
  },

  openFullsizePreview() {
    if (!this.state.selectedImage) return;

    const imageUrl = this.state.selectedImage.dataset.url;
    if (!imageUrl) return;

    const preview = this.q(".js-file-upload-manager-fullsize-preview");
    const previewImage = preview.querySelector(".js-file-upload-manager-fullsize-image");
    const itemTitle = this.state.selectedImage.querySelector('.file-upload-manager-dialog--item-title');

    previewImage.src = imageUrl;
    previewImage.alt = itemTitle ? itemTitle.textContent.trim() : '';

    preview.classList.add("-opened");
  },

  closeFullsizePreview() {
    const preview = this.q(".js-file-upload-manager-fullsize-preview");
    if (!preview) return;

    preview.classList.remove("-opened");

    const previewImage = preview.querySelector(".js-file-upload-manager-fullsize-image");
    previewImage.removeAttribute('src');
    previewImage.alt = '';
  },

  async openInfoModal() {
    if (!this.state.selectedImage) return;

    const imageId = this.state.selectedImage.dataset.id;
    const infoModal = this.q(".js-file-upload-manager-info-modal");
    const contentContainer = infoModal.querySelector(".js-file-upload-manager-info-content");

    contentContainer.innerHTML = '';
    infoModal.classList.add("-opened", "-loading");

    const endpoint = this.infoEndpoints[this.state.type] || this.infoEndpoints.picture;

    try {
      const response = await fetch(`${endpoint}/${imageId}`, {
        method: 'GET',
        headers: {
          'Accept': 'text/html',
          'X-CSRF-TOKEN': $('meta[name="csrf-token"]').attr('content')
        }
      });

      contentContainer.innerHTML = await response.text();
    } catch (error) {
      console.error('Error fetching file info:', error);
    } finally {
      infoModal.classList.remove("-loading");
    }
  },

  closeInfoModal() {
    const infoModal = this.q(".js-file-upload-manager-info-modal");
    if (!infoModal) return;

    infoModal.classList.remove("-opened", "-loading");
    infoModal.querySelector(".js-file-upload-manager-info-content").innerHTML = '';
  },

  openEditModal(e) {
    if (!this.state.selectedImage) return;

    const editModal = this.q(".js-file-upload-manager-edit-modal");
    editModal.classList.add("-opened");

    const titleInput = editModal.querySelector(".js-file-upload-manager-edit-title");

    titleInput.value = (this.state.selectedImage.querySelector('.file-upload-manager-dialog--item-title').textContent || '').trim();
  },

  closeEditModal(e) {
    this.$q(".js-file-upload-manager-edit-modal").removeClass("-opened");
  },

  async updateImage(e) {
    if (!this.state.selectedImage) return;

    const modal = this.q(".js-file-upload-manager-edit-modal");
    const titleInput = modal.querySelector(".js-file-upload-manager-edit-title");

    const formData = new FormData();
    const type = this.state.type
    const modelKey = type === 'picture' ? 'image' : 'document';
    formData.append(`${modelKey}[title]`, titleInput.value);

    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    try {
      const response = await fetch(`${this.uploadEndpoints[this.state.type]}/${this.state.selectedImage.dataset.id}`, {
        method: 'PATCH',
        headers: {
          'X-CSRF-TOKEN': csrfToken
        },
        body: formData
      });

      const data = await response.json();

      if (data.id) {
        this.closeEditModal();
        await this.fetchImageItems();
      }
    } catch (error) {
      console.error('Error updating file:', error);
      alert('Fehler beim Aktualisieren der Datei');
    }
  },

  async deleteImage(e) {
    if (!this.state.selectedImage) return;

    if (!confirm('Möchten Sie diese Datei wirklich löschen?')) {
      return;
    }

    const chosenId = this.state.selectedImage.dataset.id;
    const csrfToken = $('meta[name="csrf-token"]').attr('content');

    try {
      const response = await fetch(`${this.uploadEndpoints[this.state.type]}/${chosenId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-TOKEN': csrfToken
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
      console.error('Error deleting file:', error);
      alert('Fehler beim Löschen der Datei');
    }
  }
}
