ProjektStudio.FileImport = {
  maxFileSize: 10485760,
  allowedExtensions: ['pdf', 'docx', 'odt'],
  statusCheckTimeout: 7000,
  statusCheckActive: false,

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
    $document.on("turbolinks:before-visit", () => {
      this.stopStatusCheck();
    });
    this.checkAndShowFlashMessage();
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
    this.hideLoader();

    const successData = {
      message: 'Dokument wurde erfolgreich importiert',
      categories: response.categories || [],
      sdg_codes: response.sdg_codes || []
    };

    sessionStorage.setItem('projektFileImportSuccess', JSON.stringify(successData));
    window.location.href = window.location.pathname + '#page-content';
    location.reload();
  },

  handleError(error) {
    alert(error.message);
  },

  showLoader() {
    $(".js-projekt-file-import-trigger").prop("disabled", true).hide();
    $(".js-projekt-file-import-loader").show();
  },

  hideLoader() {
    $(".js-projekt-file-import-trigger").prop("disabled", false).show();
    $(".js-projekt-file-import-loader").hide();
    $(".js-projekt-file-import-input").val('');
  },

  checkAndShowFlashMessage() {
    const successData = sessionStorage.getItem('projektFileImportSuccess');
    if (successData) {
      sessionStorage.removeItem('projektFileImportSuccess');
      try {
        const data = JSON.parse(successData);
        this.showImportSuccessMessage(data);
      } catch (e) {
        this.showFlashMessage(successData, 'success');
      }
    }
  },

  showImportSuccessMessage(data) {
    let detailsHtml = '';

    if (data.categories && data.categories.length > 0) {
      const categoriesList = data.categories.map(cat => `<span class="label secondary">${cat}</span>`).join(' ');
      detailsHtml += `<div style="margin-top: 10px;"><strong>Kategorien:</strong> ${categoriesList}</div>`;
    }

    if (data.sdg_codes && data.sdg_codes.length > 0) {
      const sdgList = data.sdg_codes.map(code => `<span class="label primary">SDG ${code}</span>`).join(' ');
      detailsHtml += `<div style="margin-top: 10px;"><strong>SDG-Ziele:</strong> ${sdgList}</div>`;
    }

    const flashHtml = `
      <div id="success" data-alert class="notice-container callout-slide" data-closable>
        <div class="callout notice success">
          <button class="close-button" aria-label="Schließen" type="button" data-close>
            <span aria-hidden="true">&times;</span>
          </button>
          <div class="notice-text" role="alert" tabindex="-1" autofocus>
            ${data.message}
            ${detailsHtml}
          </div>
        </div>
      </div>
    `;

    $('body').prepend(flashHtml);

    const $flashElement = $('#success');
    $flashElement.find('[data-close]').on('click', function() {
      $flashElement.remove();
    });

    setTimeout(() => {
      $flashElement.remove();
    }, 8000);
  },

  showFlashMessage(message, type) {
    const flashHtml = `
      <div id="${type}" data-alert class="notice-container callout-slide" data-closable>
        <div class="callout notice ${type}">
          <button class="close-button" aria-label="Schließen" type="button" data-close>
            <span aria-hidden="true">&times;</span>
          </button>
          <div class="notice-text" role="alert" tabindex="-1" autofocus>
            ${message}
          </div>
        </div>
      </div>
    `;

    $('body').prepend(flashHtml);

    const $flashElement = $(`#${type}`);
    $flashElement.find('[data-close]').on('click', function() {
      $flashElement.remove();
    });

    setTimeout(() => {
      $flashElement.remove();
    }, 5000);
  }
};
