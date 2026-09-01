(function() {
  "use strict";

  App.SimilarContributionsCheck = {
    initialize: function() {
      const section = this.getSection();

      if (!section) {
        return;
      }

      this.pollInterval = parseInt(section.dataset.pollInterval, 10);
      this.pollTimeout = parseInt(section.dataset.pollTimeout, 10);
      this.statusUrl = section.dataset.statusUrl;
      this.publishUrl = section.dataset.publishUrl;
      this.submitting = false;
      this.publishing = false;

      this.bindFormSubmit();
      this.bindPublishButtons();

      if (this.statusUrl) {
        this.startPolling();
      }
    },

    controlsForm: function(form) {
      const section = this.getSection();

      return !!section && section.dataset.formId === form.id;
    },

    getSection: function() {
      return document.querySelector(".js-similar-contributions-check");
    },

    getForm: function() {
      return document.getElementById(this.getSection().dataset.formId);
    },

    getSubmitButton: function() {
      const form = this.getForm();

      return form && form.querySelector(".js-user-resource-submit");
    },

    getProgress: function() {
      return document.querySelector(".js-similar-contributions-progress");
    },

    getResultContainer: function() {
      return this.getSection().querySelector(".js-similar-contributions-check-result");
    },

    bindFormSubmit: function() {
      const form = this.getForm();

      if (!form) {
        return;
      }

      this.boundHandleSubmit = (event) => this.handleSubmit(event);

      form.addEventListener("submit", this.boundHandleSubmit);
    },

    bindPublishButtons: function() {
      this.boundHandleDocumentClick = (event) => {
        const publishButton = event.target.closest(".js-similar-contributions-publish");

        if (publishButton) {
          this.handlePublishClick(publishButton);
        }
      };

      document.addEventListener("click", this.boundHandleDocumentClick);
    },

    handleSubmit: function(event) {
      event.preventDefault();

      if (this.submitting) {
        return;
      }

      this.submitting = true;

      this.showProgress();
      this.clearEditorPlaceholders();
      this.syncRichTextEditors();
      this.submitForm();
    },

    clearEditorPlaceholders: function() {
      if (App.CkeEditorPlaceholder) {
        App.CkeEditorPlaceholder.clearPlaceholders();
      }
    },

    // The in-flight state is set before the request so the citizen sees the
    // spinner the instant they click, not once the server has answered.
    showProgress: function() {
      const submitButton = this.getSubmitButton();
      const progress = this.getProgress();
      const errorsContainer = this.getErrorsContainer();

      if (errorsContainer) {
        errorsContainer.innerHTML = "";
      }

      if (submitButton) {
        submitButton.hidden = true;
      }

      if (progress) {
        progress.hidden = false;
      }
    },

    restoreSubmitButton: function() {
      const submitButton = this.getSubmitButton();
      const progress = this.getProgress();

      if (progress) {
        progress.hidden = true;
      }

      if (submitButton) {
        submitButton.hidden = false;
      }

      this.submitting = false;
    },

    // CKEditor writes back to its source textarea on native form submission,
    // which never happens here, so the editors are flushed by hand before the
    // form data is read.
    syncRichTextEditors: function() {
      const form = this.getForm();
      const editors = (App.HTMLEditor && App.HTMLEditor.instances) || {};

      Object.keys(editors).forEach((editorKey) => {
        const editor = editors[editorKey];

        if (editor.sourceElement && form.contains(editor.sourceElement)) {
          editor.updateSourceElement();
        }
      });
    },

    submitForm: function() {
      const form = this.getForm();

      App.Ajax
        .request({
          url: form.action,
          method: "POST",
          data: new FormData(form),
          processData: false,
          contentType: false,
          dataType: "json"
        })
        .then((response) => this.handleCreateResponse(response))
        .catch((request) => this.handleCreateError(request));
    },

    handleCreateResponse: function(response) {
      if (response.status === "published") {
        this.redirect(response.redirect_url);
        return;
      }

      this.statusUrl = response.status_url;
      this.publishUrl = response.publish_url;

      this.startPolling();
    },

    handleCreateError: function(request) {
      const payload = request && request.responseJSON;

      if (payload && payload.status === "invalid") {
        this.showFormErrors(payload.errors_html);
        return;
      }

      console.error("[SimilarContributionsCheck] create request failed", request);

      this.restoreSubmitButton();
    },

    getErrorsContainer: function() {
      return document.querySelector(".js-user-resource-form-errors");
    },

    showFormErrors: function(errorsHtml) {
      const errorsContainer = this.getErrorsContainer();

      this.restoreSubmitButton();

      if (errorsContainer) {
        errorsContainer.innerHTML = errorsHtml;
        errorsContainer.scrollIntoView({ behavior: "smooth", block: "start" });
      }
    },

    startPolling: function() {
      this.startedAt = Date.now();

      this.scheduleCheck();
    },

    scheduleCheck: function() {
      this.timer = window.setTimeout(() => this.check(), this.pollInterval);
    },

    // The citizen is blocked on this, so a stalled queue must not strand them:
    // once the ceiling is reached the contribution is published as if the check
    // had come back empty.
    check: function() {
      if (Date.now() - this.startedAt > this.pollTimeout) {
        this.publish(this.publishUrl);
        return;
      }

      App.Ajax
        .request({ url: this.statusUrl, method: "GET", dataType: "json" })
        .then((response) => this.handleStatus(response))
        .catch((request) => this.handleStatusError(request));
    },

    // A server that answered with an error is broken, not busy: retrying it for
    // the whole timeout window hides the fault and leaves the citizen waiting.
    // Only a request that never reached the server (status 0) is worth retrying.
    handleStatusError: function(request) {
      if (request && request.status > 0) {
        console.error("[SimilarContributionsCheck] status endpoint returned " + request.status);
        this.publish(this.publishUrl);
        return;
      }

      this.scheduleCheck();
    },

    handleStatus: function(response) {
      if (response.status === "failed") {
        this.publish(this.publishUrl);
        return;
      }

      if (response.status !== "completed") {
        this.scheduleCheck();
        return;
      }

      if (response.matches_count > 0) {
        this.showMatches(response.html);
      } else {
        this.publish(this.publishUrl);
      }
    },

    showMatches: function(html) {
      const progress = this.getProgress();
      const resultContainer = this.getResultContainer();

      if (progress) {
        progress.hidden = true;
      }

      resultContainer.innerHTML = html;
      resultContainer.scrollIntoView({ behavior: "smooth", block: "start" });
    },

    handlePublishClick: function(publishButton) {
      publishButton.disabled = true;

      this.publish(publishButton.dataset.publishUrl);
    },

    publish: function(publishUrl) {
      if (this.publishing) {
        return;
      }

      this.publishing = true;

      App.Ajax
        .request({ url: publishUrl, method: "PATCH", dataType: "json" })
        .then((response) => this.redirect(response.redirect_url))
        .catch((request) => this.handlePublishError(request));
    },

    handlePublishError: function(request) {
      console.error("[SimilarContributionsCheck] publish request failed", request);

      this.publishing = false;

      const publishButton = document.querySelector(".js-similar-contributions-publish");

      if (publishButton) {
        publishButton.disabled = false;
      } else {
        this.restoreSubmitButton();
      }
    },

    redirect: function(url) {
      window.location.assign(url);
    },

    destroy: function() {
      window.clearTimeout(this.timer);

      if (this.boundHandleDocumentClick) {
        document.removeEventListener("click", this.boundHandleDocumentClick);
        this.boundHandleDocumentClick = null;
      }
    }
  };
}).call(this);
