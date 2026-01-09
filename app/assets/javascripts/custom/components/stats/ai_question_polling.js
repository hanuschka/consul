(function() {
  "use strict";

  App.AiQuestionPolling = {
    pollInterval: 5000,
    timers: {},

    initialize: function() {
      this.bindFormSubmit();
      this.startPollingForPendingQuestions();
      this.updateFormState();
    },

    bindFormSubmit: function() {
      $(document).on("submit", ".js-ai-question-form", (e) => {
        e.preventDefault();

        const $form = $(e.currentTarget);
        const $input = $(".js-ai-question-input");
        const $submit = $(".js-ai-question-submit");
        const $loading = $(".js-ai-question-loading");
        const questionValue = $input.val().trim();

        if (!questionValue) return;

        const formData = $form.serialize();

        $input.prop("disabled", true);
        $submit.prop("disabled", true);
        $input.val("");
        $loading.removeClass("hidden");

        $.ajax({
          url: $form.attr("action"),
          method: "POST",
          data: formData,
          dataType: "json",
          headers: {
            "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
          }
        })
        .then((data) => {
          $loading.addClass("hidden");
          this.handleSubmitSuccess(data);
        })
        .catch((xhr) => {
          $loading.addClass("hidden");
          this.handleSubmitError(xhr);
        });
      });
    },

    handleSubmitSuccess: function(data) {
      const container = document.querySelector(".participation-stats-ai-question");
      const pendingSection = document.querySelector(".js-ai-questions-pending");
      const pendingList = document.querySelector(".js-ai-questions-pending-list");

      if (!container || !pendingSection || !pendingList) return;

      const processingMessage = container.dataset.processingMessage;
      const questionText = data.question.length > 150
        ? data.question.substring(0, 150) + "..."
        : data.question;

      const pendingItem = document.createElement("div");
      pendingItem.className = "ai-question-item ai-question-item--pending";
      pendingItem.dataset.questionId = data.id;
      pendingItem.dataset.statusUrl = data.status_url;
      pendingItem.innerHTML = `
        <div class="shared-spinner shared-spinner--medium"></div>
        <p class="ai-question-item--text">${this.escapeHtml(questionText)}</p>
        <p class="ai-question-item--status">${processingMessage}</p>
      `;

      pendingList.insertBefore(pendingItem, pendingList.firstChild);
      pendingSection.classList.remove("hidden");

      this.pollStatus(data.id, data.status_url, pendingItem);
      this.updateFormState();
    },

    handleSubmitError: function(xhr) {
      let message = "Error creating question";
      try {
        const response = JSON.parse(xhr.responseText);
        if (response.error) message = response.error;
      } catch (e) {}
      alert(message);
      this.updateFormState();
    },

    startPollingForPendingQuestions: function() {
      const pendingItems = document.querySelectorAll(".ai-question-item--pending");

      pendingItems.forEach((item) => {
        const questionId = item.dataset.questionId;
        const statusUrl = item.dataset.statusUrl;

        if (questionId && statusUrl && !this.timers[questionId]) {
          this.pollStatus(questionId, statusUrl, item);
        }
      });
    },

    pollStatus: function(questionId, statusUrl, element) {
      this.timers[questionId] = setInterval(() => {
        $.ajax({
          url: statusUrl,
          method: "GET",
          dataType: "json"
        })
        .then((data) => {
          if (data.status === "completed") {
            clearInterval(this.timers[questionId]);
            delete this.timers[questionId];
            this.handleQuestionCompleted(data, element);
          } else if (data.status === "failed") {
            clearInterval(this.timers[questionId]);
            delete this.timers[questionId];
            element.remove();
            this.updatePendingSection();
            this.updateFormState();
          }
        })
        .catch((error) => {
          console.error("Error polling AI question status:", error);
        });
      }, this.pollInterval);
    },

    handleQuestionCompleted: function(data, pendingElement) {
      const historySection = document.querySelector(".js-ai-questions-history");

      if (data.html && historySection) {
        historySection.classList.remove("hidden");
        historySection.insertAdjacentHTML("afterbegin", data.html);
      }

      pendingElement.remove();
      this.updatePendingSection();
      this.updateFormState();
    },

    updatePendingSection: function() {
      const pendingSection = document.querySelector(".js-ai-questions-pending");
      const pendingList = document.querySelector(".js-ai-questions-pending-list");

      if (pendingList.children.length === 0) {
        pendingSection.classList.add("hidden");
      }
    },

    updateFormState: function() {
      const hasPending =
        Object.keys(this.timers).length > 0 ||
          $(".ai-question-item--pending").length > 0;

      $(".js-ai-question-input").prop("disabled", hasPending)
      $(".js-ai-question-submit").prop("disabled", hasPending)
    },

    escapeHtml: function(text) {
      const div = document.createElement("div");
      div.textContent = text;
      return div.innerHTML;
    }
  };
}).call(this);
