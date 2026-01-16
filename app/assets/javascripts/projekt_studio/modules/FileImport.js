ProjektStudio.FileImport = {
  maxFileSize: 10485760,
  allowedExtensions: ['pdf', 'docx', 'odt'],

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

    this.uploadFile(file);
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

  uploadFile(file) {
    this.showLoader();

    const projektId = ProjektStudio.getCurrentProjektId();
    const formData = new FormData();
    formData.append('file', file);

    App.Ajax.request({
      url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks/import_document`,
      type: "POST",
      dataType: "json",
      contentType: false,
      processData: false,
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
      data: formData
    })
      .then((data) => {
        this.hideLoader();

        if (data.error) {
          this.handleError(data.error);
        } else {
          location.reload();
        }
      })
      .catch(() => {
        this.hideLoader();
        alert("Netzwerkfehler beim Upload");
      });
  },

  handleError(error) {
    if (error.fallback_text) {
      this.createFallbackContentBlock(error.fallback_text, error.message);
    } else {
      alert(error.message);
    }
  },

  createFallbackContentBlock(rawText, errorMessage) {
    const fallbackConfirmed = confirm(
      `${errorMessage}\n\nMöchten Sie den Rohtext als einzelnen Inhaltsblock erstellen?`
    );

    if (!fallbackConfirmed) {
      return;
    }

    const projektId = ProjektStudio.getCurrentProjektId();
    const escapedText = this.escapeHtml(rawText);
    const html = `<div class="imported-raw-text"><pre>${escapedText}</pre></div>`;

    $.ajax({
      url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks`,
      type: "POST",
      dataType: "json",
      headers: {
        'X-Embedded-Frame': ProjektStudio.isEmbedded
      },
      data: { html: html }
    })
      .then(() => {
        location.reload();
      })
      .catch(() => {
        alert("Fehler beim Erstellen des Fallback-Inhaltsblocks");
      });
  },

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  },

  showLoader() {
    $(".js-projekt-file-import-trigger").prop("disabled", true).hide();
    $(".js-projekt-file-import-loader").show();
  },

  hideLoader() {
    $(".js-projekt-file-import-trigger").prop("disabled", false).show();
    $(".js-projekt-file-import-loader").hide();
    $(".js-projekt-file-import-input").val('');
  }
};
