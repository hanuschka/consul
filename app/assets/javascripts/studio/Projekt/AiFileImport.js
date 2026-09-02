App.Studio.Projekt.AiFileImport = {
  maxFileSize: 524288000,
  allowedExtensions: ['pdf', 'docx', 'odt'],
  statusCheckTimeout: 7000,
  statusCheckActive: false,
  selectedFile: null,

  initialize() {
    const $document = $(document);

    $document.on("click", ".js-projekt-file-import-trigger", this.handleButtonClick.bind(this));
    $document.on("change", ".js-projekt-file-import-input", this.handleFileSelect.bind(this));
    $document.on("click", ".js-projekt-file-import-submit", this.handleSubmit.bind(this));
    $document.on("click", ".js-projekt-file-import-cancel", this.handleCancel.bind(this));
    $document.on("click", ".js-projekt-file-import-select-other", this.handleSelectOther.bind(this));
    $document.on("turbolinks:before-visit", () => { this.stopStatusCheck(); });
  },

  handleButtonClick(e) {
    e.preventDefault();

    if (App.Studio.Projekt.isAiTriggerDisabled(e.currentTarget)) return;

    this.showFileImportForm();
  },

  showFileImportForm() {
    $(".js-projekt-content-start-buttons").hide();
    $(".js-content-start-section--title").hide();
    $(".projekt-file-import-preview-info").hide();
    $(".js-projekt-file-import-submit").prop("disabled", true);
    $(".js-projekt-file-import-preview").show();
  },

  handleFileSelect(e) {
    const file = e.target.files[0];
    if (!file) return;

    const validation = this.validateFile(file);
    if (!validation.valid) {
      alert(validation.error);
      e.target.value = '';
      return;
    }

    this.selectedFile = file;
    this.showFilePreview(file);
  },

  showFilePreview(file) {
    const extension = file.name.split('.').pop().toLowerCase();
    const iconClass = this.getFileIconClass(extension);
    const displayName = this.truncateFilename(file.name, 80);

    $(".js-projekt-file-import-filename").text(displayName);
    $(".js-projekt-file-import-icon").removeClass().addClass(`fas ${iconClass} js-projekt-file-import-icon`);
    $(".projekt-file-import-preview-info").removeClass("-pdf -docx -odt").addClass(`-${extension}`).show();
    $(".js-projekt-file-import-submit").prop("disabled", false);
    $(".js-projekt-content-start-buttons").hide();
    $(".js-content-start-section--title").hide();
    $(".js-projekt-file-import-preview").show();
    $(".js-projekt-file-import-user-prompt").focus();
  },

  getFileIconClass(extension) {
    const iconMap = {
      pdf: 'fa-file-pdf',
      docx: 'fa-file-word',
      odt: 'fa-file-alt'
    };
    return iconMap[extension] || 'fa-file';
  },

  truncateFilename(filename, maxLength) {
    if (filename.length <= maxLength) {
      return filename;
    }

    const extension = filename.split('.').pop();
    const nameWithoutExt = filename.slice(0, -(extension.length + 1));
    const availableLength = maxLength - extension.length - 4;
    const halfLength = Math.floor(availableLength / 2);

    const start = nameWithoutExt.slice(0, halfLength);
    const end = nameWithoutExt.slice(-halfLength);

    return `${start}...${end}.${extension}`;
  },

  handleSubmit(e) {
    e.preventDefault();
    if (!this.selectedFile) return;

    const userPrompt = $(".js-projekt-file-import-user-prompt").val().trim();
    this.uploadFile(this.selectedFile, userPrompt);
  },

  handleCancel(e) {
    e.preventDefault();
    this.resetFileSelection();
  },

  handleSelectOther(e) {
    e.preventDefault();
    $(".js-projekt-file-import-input").val('');
    $(".js-projekt-file-import-input").click();
  },

  resetFileSelection() {
    this.selectedFile = null;
    $(".js-projekt-file-import-input").val('');
    $(".js-projekt-file-import-user-prompt").val('');
    $(".projekt-file-import-preview-info").removeClass("-pdf -docx -odt");
    $(".js-projekt-file-import-preview").hide();
    $(".js-projekt-content-start-buttons").show();
    $(".js-content-start-section--title").show();
  },

  validateFile(file) {
    const extension = file.name.split('.').pop().toLowerCase();

    if (!this.allowedExtensions.includes(extension)) {
      return {
        valid: false,
        error: "Ungültiges Dateiformat. Bitte laden Sie eine PDF, DOCX oder ODT Datei hoch."
      };
    }

    if (file.size > this.maxFileSize) {
      return {
        valid: false,
        error: "Datei ist zu groß (max. 500MB)"
      };
    }

    return { valid: true };
  },

  uploadFile(file, userPrompt) {
    this.showLoader();

    const projektId = App.Studio.Projekt.getCurrentProjektId();
    const formData = new FormData();
    formData.append('file', file);
    if (userPrompt) {
      formData.append('user_prompt', userPrompt);
    }

    App.Ajax
      .request({
        url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks/ai_generate_with_file`,
        type: "POST",
        dataType: "json",
        contentType: false,
        processData: false,
        data: formData
      })
      .then((data) => {
        if (data.error) {
          this.hideLoader();
          this.handleError(data.error);
        } else if (data.status_url) {
          this.startStatusCheck(data.status_url);
        } else {
          this.hideLoader();
          location.reload();
        }
      })
      .catch(() => {
        this.hideLoader();
        alert("Netzwerkfehler beim Upload");
      });
  },

  startStatusCheck(statusUrl) {
    this.statusCheckActive = true;
    this.statusCheckAttempts = 0;
    this.poll(statusUrl);
  },

  poll(statusUrl) {
    if (!this.statusCheckActive) {
      return;
    }

    if (this.statusCheckAttempts >= 300) {
      this.handleStatusCheckTimeout();
      return;
    }

    this.statusCheckAttempts++;

    App.Ajax
      .request({
        url: statusUrl,
        method: "GET",
        dataType: "json"
      })
      .then((response) => this.handleStatusResponse(response, statusUrl))
      .catch(() => this.handleStatusCheckError(statusUrl));
  },

  handleStatusCheckTimeout() {
    this.statusCheckActive = false;
    this.hideLoader();
    alert("Timeout beim Importieren des Dokuments. Bitte versuchen Sie es erneut.");
  },

  handleStatusResponse(response, statusUrl) {
    if (!this.statusCheckActive) {
      return;
    }

    if (response.status === "completed") {
      this.statusCheckActive = false;
      window.location.reload()
    } else if (response.status === "failed") {
      this.handleStatusCheckFailure(response);
    } else {
      setTimeout(() => this.poll(statusUrl), this.statusCheckTimeout);
    }
  },

  handleStatusCheckFailure(response) {
    this.statusCheckActive = false;
    this.hideLoader();
    if (response.error) {
      this.handleError(response.error);
    } else {
      alert("Fehler beim Importieren des Dokuments. Bitte versuchen Sie es erneut.");
    }
  },

  handleStatusCheckError(statusUrl) {
    if (this.statusCheckActive) {
      setTimeout(() => this.poll(statusUrl), this.statusCheckTimeout);
    }
  },

  stopStatusCheck() {
    this.statusCheckActive = false;
  },

  handleError(error) {
    alert(error.message);
  },

  showLoader(message = "Dokument wird verarbeitet...") {
    $(".js-projekt-file-import-preview").hide();
    $(".js-projekt-start-with-prompt-form").hide();
    $(".js-projekt-content-start-buttons").hide();
    $(".js-content-start-section--title").hide();
    $(".js-projekt-loader-message").text(message);
    $(".js-projekt-file-import-loader").show();
  },

  hideLoader() {
    $(".js-projekt-file-import-loader").hide();
    $(".js-projekt-file-import-preview").show();
    this.resetFileSelection();
  },

};
