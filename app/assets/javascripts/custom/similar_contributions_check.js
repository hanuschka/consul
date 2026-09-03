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
      this.bindModalButtons();
      this.bindVoteRefresh();

      if (this.statusUrl) {
        this.openModal();
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

    getModal: function() {
      return this.getSection().querySelector(".js-similar-contributions-notice-modal");
    },

    getModalProgress: function() {
      return this.getSection().querySelector(".js-similar-contributions-modal-progress");
    },

    bindFormSubmit: function() {
      const form = this.getForm();

      if (!form) {
        return;
      }

      this.boundHandleSubmit = (event) => this.handleSubmit(event);

      form.addEventListener("submit", this.boundHandleSubmit);
    },

    bindModalButtons: function() {
      this.boundHandleDocumentClick = (event) => {
        const publishButton = event.target.closest(".js-similar-contributions-publish");

        if (publishButton) {
          this.handlePublishClick(publishButton);
          return;
        }

        if (event.target.closest(".js-similar-contributions-dismiss")) {
          this.dismissModal();
          return;
        }

        const duplicatesToggle = event.target.closest(".js-similar-contributions-show-duplicates");

        if (duplicatesToggle) {
          this.toggleDecisionMatches(duplicatesToggle);
          return;
        }

        if (event.target.closest(".js-similar-contributions-submit-anyway")) {
          this.handleSubmitAnywayClick(event.target.closest(".js-similar-contributions-submit-anyway"));
        }
      };

      document.addEventListener("click", this.boundHandleDocumentClick);
    },

    // A vote response replaces the match's whole votes markup, which detaches
    // the form that sent the request -- so its own ajax:success never reaches
    // the document. jQuery's global ajax event fires on the document itself
    // and survives that.
    bindVoteRefresh: function() {
      this.boundRefreshSupportedState = () => this.refreshSupportedState();

      $(document).on("ajaxComplete", this.boundRefreshSupportedState);
    },

    // The modal and the decision block on the form both offer the matches with
    // their own vote markup, and both are in the document at the same time, so
    // each one is resolved against its own links instead of the document's.
    refreshSupportedState: function() {
      const surfaces = document.querySelectorAll(".js-similar-contributions-support-surface");

      surfaces.forEach((surface) => this.refreshSurfaceSupportedState(surface));
    },

    // "unvote" is the support button of a single-support phase once it is
    // supported; "like voted" is the up-and-down-voting variant of the same
    // state.
    refreshSurfaceSupportedState: function(surface) {
      const supportedLinks = surface.querySelectorAll(".js-similar-contributions-supported-link");

      if (supportedLinks.length === 0) {
        return;
      }

      let anySupported = false;

      supportedLinks.forEach((supportedLink) => {
        const votesContainer = document.getElementById(supportedLink.dataset.votesContainer);
        const supported = !!votesContainer && !!votesContainer.querySelector(".unvote, .like.voted");

        supportedLink.hidden = !supported;

        if (supported) {
          anySupported = true;
        }
      });

      const defaultActions = surface.querySelector(".js-similar-contributions-default-actions");

      if (defaultActions) {
        defaultActions.hidden = anySupported;
      }
    },

    handleSubmit: function(event) {
      event.preventDefault();

      if (this.submitting) {
        return;
      }

      this.submitting = true;

      this.hideDecisionActions();
      this.showProgress();
      this.openModal();
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

    // rails-ujs disables every data-disable-with control on the submit event
    // and only re-enables them for forms it submits itself. This form is
    // submitted by hand, so without enableElement the button stays dead after
    // a validation error and the citizen cannot resubmit at all.
    restoreSubmitButton: function() {
      const submitButton = this.getSubmitButton();
      const progress = this.getProgress();
      const form = this.getForm();

      if (progress) {
        progress.hidden = true;
      }

      if (submitButton) {
        submitButton.hidden = false;
      }

      if (window.Rails && form) {
        window.Rails.enableElement(form);
      }

      this.submitting = false;
    },

    // The modal carries the whole check: the spinner while it runs, the matches
    // once they are in. It is opened the instant the citizen submits, so the
    // wait happens on the surface that will hold the answer.
    openModal: function() {
      App.SharedModal.open(this.getModal().id);
    },

    closeModal: function() {
      App.SharedModal.closeById(this.getModal().id);
    },

    // Back to the form: the form swaps its plain submit button for the two ways
    // out of the decision -- read the matches again, now listed on the form
    // itself, or submit anyway.
    dismissModal: function() {
      this.closeModal();
      this.showDecisionActions();
    },

    getDecisionActions: function() {
      return document.querySelector(".js-similar-contributions-decision");
    },

    // The decision block on the form is the one the server rendered before the
    // check ran, so it holds no matches. Swapping in the re-rendered one puts
    // them under the form, where the citizen decides.
    replaceDecisionActions: function(decisionHtml) {
      const decisionActions = this.getDecisionActions();

      if (!decisionActions || !decisionHtml) {
        return;
      }

      decisionActions.outerHTML = decisionHtml;
    },

    toggleDecisionMatches: function(toggle) {
      const matches = document.getElementById(toggle.getAttribute("aria-controls"));

      if (!matches) {
        return;
      }

      const shouldExpand = matches.hidden;
      const label = toggle.querySelector(".js-similar-contributions-toggle-label");

      matches.hidden = !shouldExpand;
      toggle.setAttribute("aria-expanded", shouldExpand);

      if (label) {
        label.textContent = shouldExpand ? toggle.dataset.labelExpanded : toggle.dataset.labelCollapsed;
      }
    },

    showDecisionActions: function() {
      const submitButton = this.getSubmitButton();
      const decisionActions = this.getDecisionActions();

      if (submitButton) {
        submitButton.hidden = true;
      }

      if (decisionActions) {
        decisionActions.hidden = false;
      }
    },

    hideDecisionActions: function() {
      const decisionActions = this.getDecisionActions();

      if (decisionActions) {
        decisionActions.hidden = true;
      }
    },

    handleSubmitAnywayClick: function(button) {
      button.disabled = true;

      this.publish(this.publishUrl);
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

      this.closeModal();
      this.restoreSubmitButton();
    },

    getErrorsContainer: function() {
      return document.querySelector(".js-user-resource-form-errors");
    },

    showFormErrors: function(errorsHtml) {
      const errorsContainer = this.getErrorsContainer();

      this.closeModal();
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
        this.showMatches(response);
      } else {
        this.publish(this.publishUrl);
      }
    },

    // The form leaves its in-flight state before the modal opens, not when the
    // modal is dismissed: a native dialog makes the page behind it inert, so
    // the restored submit button cannot be clicked while the decision is open,
    // and it is already there whichever way the citizen dismisses the modal --
    // no dependency on the dialog "close" event.
    showMatches: function(response) {
      this.restoreSubmitButton();
      this.replaceDecisionActions(response.decision_html);

      this.getResultContainer().innerHTML = response.html;
      this.getModalProgress().hidden = true;
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

      const publishButtons = document.querySelectorAll(
        ".js-similar-contributions-publish, .js-similar-contributions-submit-anyway"
      );

      if (publishButtons.length > 0) {
        publishButtons.forEach((publishButton) => { publishButton.disabled = false; });
        return;
      }

      this.closeModal();
      this.restoreSubmitButton();
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

      if (this.boundRefreshSupportedState) {
        $(document).off("ajaxComplete", this.boundRefreshSupportedState);
        this.boundRefreshSupportedState = null;
      }
    }
  };
}).call(this);
