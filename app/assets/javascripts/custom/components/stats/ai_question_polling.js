(function() {
  "use strict";

  App.AiQuestionPolling = {
    pollInterval: 5000,
    timers: {},

    initialize: function() {
      this.setupEventListeners();
      this.startPollingForPendingQuestions();
      this.updateFormState();
    },

    setupEventListeners: function() {
      $(document).on("submit", ".js-ai-question-form", this.handleFormSubmit.bind(this));
      $(document).on("click", ".js-delete-stat-question", this.handleDelete.bind(this));
    },

    handleFormSubmit: function(e) {
      e.preventDefault();

      const $form = $(e.currentTarget);
      const $input = $(".js-ai-question-input");
      const questionValue = $input.val().trim();

      if (!questionValue) return;

      const formData = $form.serialize();

      $input
        .add(".js-ai-question-submit")
        .prop("disabled", true);

      $input.val("");

      $(".js-ai-question-loading").removeClass("hidden");

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
          $(".js-ai-question-loading").addClass("hidden");
          this.handleSubmitSuccess(data);
        })
        .catch((xhr) => {
          $(".js-ai-question-loading").addClass("hidden");
          this.handleSubmitError(xhr);
        });
    },

    handleSubmitSuccess: function(data) {
      const $container = $(".participation-stats-ai-question");
      const $pendingList = $(".js-ai-questions-pending-list");

      if (!$container.length || !$pendingList.length) return;

      const questionText = data.question.length > 150
        ? data.question.substring(0, 150) + "..."
        : data.question;

      const $pendingItem = $(`
        <div class="ai-question-item ai-question-item--pending"
             data-question-id="${data.id}"
             data-status-url="${data.status_url}">
          <div class="shared-spinner shared-spinner--medium"></div>
          <p class="ai-question-item--text">${$("<div>").text(questionText).html()}</p>
          <p class="ai-question-item--status">${$container.data("processing-message")}</p>
        </div>
      `);

      $pendingList.prepend($pendingItem);
      $(".js-ai-questions-pending").removeClass("hidden");

      this.pollStatus(data.id, data.status_url, $pendingItem);
      this.updateFormState();
    },

    handleSubmitError: function(xhr) {
      let message = "Fehler beim Erstellen der Frage";
      try {
        const response = JSON.parse(xhr.responseText);
        if (response.error) message = response.error;
      } catch (e) {}
      alert(message);
      this.updateFormState();
    },

    startPollingForPendingQuestions: function() {
      $(".ai-question-item--pending").each((_, item) => {
        const $item = $(item);
        const questionId = $item.data("question-id");
        const statusUrl = $item.data("status-url");

        if (questionId && statusUrl && !this.timers[questionId]) {
          this.pollStatus(questionId, statusUrl, $item);
        }
      });
    },

    pollStatus: function(questionId, statusUrl, $element) {
      this.timers[questionId] = setInterval(() => {
        $.ajax({
          url: statusUrl,
          method: "GET",
          dataType: "json"
        })
        .then((data) => {
          if (data.status === "completed") {
            this.clearTimer(questionId);
            this.handleQuestionCompleted(data, $element);
          } else if (data.status === "failed") {
            this.clearTimer(questionId);
            $element.remove();
            this.updatePendingSection();
            this.updateFormState();
          }
        })
        .catch((error) => {
          console.error("Error polling AI question status:", error);
        });
      }, this.pollInterval);
    },

    clearTimer: function(questionId) {
      clearInterval(this.timers[questionId]);
      delete this.timers[questionId];
    },

    handleQuestionCompleted: function(data, $pendingElement) {
      const $historySection = $(".js-ai-questions-history");

      if (data.html && $historySection.length) {
        $historySection
          .removeClass("hidden")
          .prepend(data.html);
      }

      $pendingElement.remove();
      this.updatePendingSection();
      this.updateFormState();
    },

    updatePendingSection: function() {
      const $pendingList = $(".js-ai-questions-pending-list");

      if ($pendingList.children().length === 0) {
        $(".js-ai-questions-pending").addClass("hidden");
      }
    },

    updateFormState: function() {
      const hasPending =
        Object.keys(this.timers).length > 0 ||
        $(".ai-question-item--pending").length > 0;

      $(".js-ai-question-input, .js-ai-question-submit").prop("disabled", hasPending);
    },

    handleDelete: function(e) {
      const $button = $(e.target).closest(".js-delete-stat-question");
      const confirmMessage = $button.data("confirm-message");

      if (!confirm(confirmMessage)) return;

      const $questionItem = $button.closest(".ai-question-item--completed");

      $questionItem.remove();

      $.ajax({
        url: $button.data("url"),
        method: "DELETE",
        dataType: "json",
        headers: {
          "X-CSRF-Token": $("meta[name='csrf-token']").attr("content")
        }
      })
      .then(() => { })
      .catch(() => {
        alert("Fehler beim Löschen der Frage");
      });
    }
  };
}).call(this);
