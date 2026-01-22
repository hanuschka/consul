ProjektStudio.FileImport = {
  maxFileSize: 10485760,
  allowedExtensions: ['pdf', 'docx', 'odt'],
  statusCheckTimeout: 7000,
  statusCheckActive: false,
  selectedFile: null,

  initialize() {
    const $document = $(document);
    $document.on(
      "click",
      ".js-projekt-file-import-trigger",
      this.handleButtonClick.bind(this)
    );
    $document.on(
      "change",
      ".js-projekt-file-import-input",
      this.handleFileSelect.bind(this)
    );
    $document.on(
      "click",
      ".js-projekt-file-import-submit",
      this.handleSubmit.bind(this)
    );
    $document.on(
      "click",
      ".js-projekt-file-import-cancel",
      this.handleCancel.bind(this)
    );
    $document.on(
      "click",
      ".js-projekt-file-import-select-other",
      this.handleSelectOther.bind(this)
    );
    $document.on("turbolinks:before-visit", () => {
      this.stopStatusCheck();
    });
  },

  handleButtonClick(e) {
    e.preventDefault();
    $(".js-projekt-file-import-input").click();
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

    $(".js-projekt-file-import-filename").text(file.name);
    $(".js-projekt-file-import-icon").removeClass().addClass(`fas ${iconClass} js-projekt-file-import-icon`);
    $(".js-projekt-file-import-trigger").hide();
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
    $(".js-projekt-file-import-preview").hide();
    $(".js-projekt-file-import-trigger").show();
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
        error: "Datei ist zu groß (max. 10MB)"
      };
    }

    return { valid: true };
  },

  uploadFile(file, userPrompt) {
    this.showLoader();

    const projektId = ProjektStudio.getCurrentProjektId();
    const formData = new FormData();
    formData.append('file', file);
    if (userPrompt) {
      formData.append('user_prompt', userPrompt);
    }

    App.Ajax
      .request({
        url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks/import_document`,
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
      this.finishStatusCheck(response);
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

  finishStatusCheck(response) {
    window.location.href = response.redirect_url;
  },

  handleError(error) {
    alert(error.message);
  },

  showLoader() {
    $(".js-projekt-file-import-preview").hide();
    $(".js-projekt-file-import-preview-header").show();
    $(".js-projekt-file-import-loader").show();
  },

  hideLoader() {
    $(".js-projekt-file-import-loader").hide();
    $(".js-projekt-file-import-preview").show();
    this.resetFileSelection();
  },

};
