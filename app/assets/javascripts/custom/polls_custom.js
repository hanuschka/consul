(function() {
  "use strict";
  App.PollsCustom = {
    resizeDebounceTimer: null,
    openAnswerAutosaveTimers: new WeakMap(),
    openAnswerStatusTimers: new WeakMap(),
    openAnswerSavesPending: new WeakMap(),

    initialize: function() {
      this.destroy();

      App.PollsCustom.showOpenAnswers();

      $("body").on("click.pollsCustom", ".js-show-open-answers", this.handleOpenAnswersToggle.bind(this));
      $("body").on("input.pollsCustom", ".js-poll-open-answer-autosave textarea", this.handleOpenAnswerInput.bind(this));

      this.formatVisibleRatingScales();

      if ($(".js-rating-scale").length > 0) {
        $(window).on("resize.pollsCustom", this.handleWindowResize);
      }
    },

    handleOpenAnswerInput: function(event) {
      const form = event.currentTarget.closest("form");
      if (!form) return;

      clearTimeout(this.openAnswerAutosaveTimers.get(form));
      this.openAnswerAutosaveTimers.set(form, setTimeout(() => {
        this.submitOpenAnswerForm(form);
      }, 500));
    },

    submitOpenAnswerForm: function(form) {
      const textarea = form.querySelector("textarea");
      if (!textarea) return;

      const savingText = form.dataset.savingText;
      const savedText = form.dataset.savedText;
      const errorText = form.dataset.errorText;

      const status = form.querySelector(".js-poll-open-answer-status");
      if (status) {
        status.textContent = savingText || "";
        status.className = "poll-open-answer-status js-poll-open-answer-status -saving";
      }

      this.openAnswerSavesPending.set(form, (this.openAnswerSavesPending.get(form) || 0) + 1);

      $(form).off(".pollsOpenAnswer");

      $(form).on("ajax:complete.pollsOpenAnswer", (_event, _xhr, outcome) => {
        const pending = this.openAnswerSavesPending.get(form) - 1;
        this.openAnswerSavesPending.set(form, pending);

        if (!status || pending > 0) return;

        clearTimeout(this.openAnswerStatusTimers.get(form));

        if (outcome !== "success") {
          status.textContent = errorText || "";
          status.className = "poll-open-answer-status js-poll-open-answer-status -error";
          return;
        }

        status.textContent = savedText || "";
        status.className = "poll-open-answer-status js-poll-open-answer-status -saved";
        this.openAnswerStatusTimers.set(form, setTimeout(() => {
          status.textContent = "";
          status.className = "poll-open-answer-status js-poll-open-answer-status";
        }, 2000));
      });

      $(form).submit();
    },

    // ".pollsCustom" is a jQuery event namespace — it tags bindings
    // so .off(".pollsCustom") removes only this module's handlers
    // without affecting other modules on the same elements.
    destroy: function() {
      $("body").off(".pollsCustom");
      $(window).off(".pollsCustom");
      clearTimeout(App.PollsCustom.resizeDebounceTimer);
    },

    showOpenAnswers: function() {
      $('.poll-results-open-answers').each(function() {
        const $element = $(this);
        const isOpen = sessionStorage.getItem($element.attr('id')) === 'true';

        $element.addClass(isOpen ? 'rotate-toggle-arrow' : 'hide-open-answers');
      });
    },

    formatRatingScale: function(element) {
      const $element = $(element);
      const $answersContainer = $element.find('.rating-scale-answer-container');
      const $parentContainer = $element.parent();

      $element.removeClass('vertical-rating-scale-answers');

      if ($answersContainer.width() > $parentContainer.width()) {
        $element.addClass('vertical-rating-scale-answers');
      }
    },

    formatVisibleRatingScales: function() {
      $(".js-rating-scale:visible").each(function() {
        App.PollsCustom.formatRatingScale(this);
      });
    },

    formatVisibleRatingScalesAfterRepaint: function() {
      requestAnimationFrame(function() {
        App.PollsCustom.formatVisibleRatingScales();
      });
    },

    handleOpenAnswersToggle: function(event) {
      const $wrapper = $(event.currentTarget).closest('.poll-results-open-answers');
      const $questionList = $(event.currentTarget).siblings('.poll-results-open-answers-list');
      const wrapperId = $wrapper.attr('id');
      const isOpen = sessionStorage.getItem(wrapperId) === 'true';

      sessionStorage.setItem(wrapperId, String(!isOpen));
      $wrapper.toggleClass('rotate-toggle-arrow', !isOpen);
      isOpen ? $questionList.hide('fast') : $questionList.show('fast');
    },

    handleWindowResize: function() {
      clearTimeout(App.PollsCustom.resizeDebounceTimer);

      App.PollsCustom.resizeDebounceTimer = setTimeout(function() {
        App.PollsCustom.formatVisibleRatingScales();
      }, 200);
    }
  };
}).call(this);
