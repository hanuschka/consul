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

        const form = e.currentTarget;
        const input = document.querySelector(".js-ai-question-input");
        const submit = document.querySelector(".js-ai-question-submit");
        const loading = document.querySelector(".js-ai-question-loading");
        const questionValue = input.value.trim();

        if (!questionValue) return;

        const formData = new FormData(form);

        input.disabled = true;
        submit.disabled = true;
        input.value = "";
        loading.classList.remove("hidden");

        fetch(form.action, {
          method: "POST",
          body: formData,
          headers: {
            "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content
          }
        })
        .then(response => response.json())
        .then((data) => {
          loading.classList.add("hidden");
          this.handleSubmitSuccess(data);
        })
        .catch((error) => {
          loading.classList.add("hidden");
          this.handleSubmitError({ responseText: JSON.stringify({ error: error.message }) });
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
        fetch(statusUrl, {
          method: "GET",
          headers: {
            "Content-Type": "application/json"
          }
        })
        .then(response => response.json())
        .then((data) => {
          if (data.status === "completed" || data.status === "failed") {
            clearInterval(this.timers[questionId]);
            delete this.timers[questionId];
            window.location.reload();
          }
        })
        .catch((error) => {
          console.error("Error polling AI question status:", error);
        });
      }, this.pollInterval);
    },

    updateFormState: function() {
      const input = document.querySelector(".js-ai-question-input");
      const submit = document.querySelector(".js-ai-question-submit");
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
