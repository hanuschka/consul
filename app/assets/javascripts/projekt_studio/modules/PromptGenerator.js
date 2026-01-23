ProjektStudio.PromptGenerator = {
  initialize() {
    const $document = $(document);

    // $document.on("click", ".js-projekt-prompt-trigger", this.handlePromptTrigger.bind(this));
    // $document.on("click", ".js-projekt-prompt-submit", this.handleSubmit.bind(this));
    // $document.on("click", ".js-projekt-prompt-cancel", this.handleCancel.bind(this));
    // $document.on("click", ".js-projekt-empty-block-trigger", this.handleEmptyBlockTrigger.bind(this));
    $document.on("click", ".js-projekt-template-trigger", this.handleTemplateTrigger.bind(this));
  },

  handlePromptTrigger(e) {
    e.preventDefault();
    $(".js-projekt-content-start-buttons").hide();
    $(".js-projekt-prompt-form").show();
    $(".js-projekt-prompt-input").focus();
  },

  handleSubmit(e) {
    e.preventDefault();
    const prompt = $(".js-projekt-prompt-input").val().trim();

    if (!prompt) {
      alert("Bitte geben Sie einen Prompt ein.");
      return;
    }

    this.generateContentFromPrompt(prompt);
  },

  handleCancel(e) {
    e.preventDefault();
    this.resetForm();
  },

  handleEmptyBlockTrigger(e) {
    e.preventDefault();
    this.createEmptyBlock();
  },

  handleTemplateTrigger(e) {
    e.preventDefault();
    this.openTemplateSelector();
  },

  generateContentFromPrompt(prompt) {
    ProjektStudio.FileImport.showLoader("Inhalte werden generiert...");

    const projektId = ProjektStudio.getCurrentProjektId();

    App.Ajax
      .request({
        url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks/generate_from_prompt`,
        type: "POST",
        dataType: "json",
        data: { prompt }
      })
      .then((data) => {
        if (data.error) {
          this.hideLoader();
          alert(data.error.message || "Fehler beim Generieren der Inhalte");
        } else if (data.status_url) {
          this.startStatusCheck(data.status_url);
        } else {
          this.hideLoader();
          location.reload();
        }
      })
      .catch(() => {
        this.hideLoader();
        alert("Netzwerkfehler beim Generieren der Inhalte");
      });
  },

  createEmptyBlock() {
    const projektId = ProjektStudio.getCurrentProjektId();
    const emptyHtml = '<div class="row"><div class="small-12 columns"><p>Neuer Inhaltsblock</p></div></div>';

    App.Ajax
      .request({
        url: `/${App.routeNamespace}/projekts/${projektId}/projekt_content_blocks`,
        type: "POST",
        dataType: "json",
        data: {
          html: emptyHtml
        }
      })
      .then((response) => {
        if (response.error) {
          alert(response.error.message || "Fehler beim Erstellen des Inhaltsblocks");
        } else {
          location.reload();
        }
      })
      .catch(() => {
        alert("Netzwerkfehler beim Erstellen des Inhaltsblocks");
      });
  },

  openTemplateSelector() {
    const container = document.querySelector(".js-projekt-content-start-section");

    if (container && $('#contentBlockTemplatesModal').length) {
      ProjektStudio.ContentBlock.Crud.addContentBlockAfter = container;
      $('#contentBlockTemplatesModal').foundation('open');
    } else {
      alert("Vorlagen-Dialog ist nicht verfügbar");
    }
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
    alert("Timeout beim Generieren der Inhalte. Bitte versuchen Sie es erneut.");
  },

  handleStatusResponse(response, statusUrl) {
    if (!this.statusCheckActive) {
      return;
    }

    if (response.status === "completed") {
      this.statusCheckActive = false;
      window.location.reload();
    } else if (response.status === "failed") {
      this.handleStatusCheckFailure(response);
    } else {
      setTimeout(() => this.poll(statusUrl), 7000);
    }
  },

  handleStatusCheckFailure(response) {
    this.statusCheckActive = false;
    this.hideLoader();
    if (response.error) {
      alert(response.error.message || "Fehler beim Generieren der Inhalte");
    } else {
      alert("Fehler beim Generieren der Inhalte. Bitte versuchen Sie es erneut.");
    }
  },

  handleStatusCheckError(statusUrl) {
    if (this.statusCheckActive) {
      setTimeout(() => this.poll(statusUrl), 7000);
    }
  },

  resetForm() {
    $(".js-projekt-prompt-input").val('');
    $(".js-projekt-prompt-form").hide();
    $(".js-projekt-content-start-buttons").show();
  },

  hideLoader() {
    $(".js-projekt-file-import-loader").hide();
    this.resetForm();
  }
};
