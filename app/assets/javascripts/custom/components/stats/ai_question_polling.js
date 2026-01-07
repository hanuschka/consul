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
      const form = document.getElementById("ai-question-form");
      if (!form) return;

      $(form).on("ajax:success", (event, data) => {
        this.handleSubmitSuccess(data);
      });

      $(form).on("ajax:error", (event, xhr) => {
        this.handleSubmitError(xhr);
      });
    },

    handleSubmitSuccess: function(data) {
      const input = document.getElementById("ai-question-input");
      const container = document.querySelector(".participation-stats-ai-question");
      const pendingSection = document.getElementById("ai-questions-pending");
      const pendingList = document.getElementById("ai-questions-pending-list");

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
        <div class="ai-question-item--spinner"></div>
        <p class="ai-question-item--text">${this.escapeHtml(questionText)}</p>
        <p class="ai-question-item--status">${processingMessage}</p>
      `;

      pendingList.insertBefore(pendingItem, pendingList.firstChild);
      pendingSection.classList.remove("hidden");

      if (input) input.value = "";

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
          type: "GET",
          dataType: "json",
          success: (data) => {
            if (data.status === "completed" || data.status === "failed") {
              clearInterval(this.timers[questionId]);
              delete this.timers[questionId];
              window.location.reload();
            }
          },
          error: (xhr, status, error) => {
            console.error("Error polling AI question status:", error);
          }
        });
      }, this.pollInterval);
    },

    updateFormState: function() {
      const input = document.getElementById("ai-question-input");
      const submit = document.getElementById("ai-question-submit");
      const hasPending = Object.keys(this.timers).length > 0 ||
                         document.querySelectorAll(".ai-question-item--pending").length > 0;

      if (input) input.disabled = hasPending;
      if (submit) submit.disabled = hasPending;
    },

    escapeHtml: function(text) {
      const div = document.createElement("div");
      div.textContent = text;
      return div.innerHTML;
    }
  };
}).call(this);
