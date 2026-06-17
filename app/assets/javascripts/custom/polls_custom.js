(function() {
  "use strict";
  App.PollsCustom = {
    resizeDebounceTimer: null,
    openAnswerAutosaveTimers: new WeakMap(),
    openAnswerStatusTimers: new WeakMap(),

    initialize: function() {
      console.log("[RS] initialize");
      this.destroy();

      App.PollsCustom.showOpenAnswers();

      $("body").on("click.pollsCustom", ".js-show-open-answers", this.handleOpenAnswersToggle.bind(this));
      $("body").on("input.pollsCustom", ".js-poll-open-answer-autosave textarea", this.handleOpenAnswerInput.bind(this));

      this.formatVisibleRatingScales();

      if (document.fonts && document.fonts.ready) {
        document.fonts.ready.then(function() {
          console.log("[RS] document.fonts.ready re-measure");
          App.PollsCustom.formatVisibleRatingScales();
        });
      }

      $("body").on(
        "click.pollsCustom",
        ".js-question-wizard-next, .js-question-wizard-prev, .js-question-wizard-go-to-start",
        this.formatVisibleRatingScalesAfterRepaint.bind(this)
      );

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

      // Capture textarea state for restore after the answers section is re-rendered.
      const wasFocused = document.activeElement === textarea;
      const selStart = textarea.selectionStart;
      const selEnd = textarea.selectionEnd;

      const status = form.querySelector(".js-poll-open-answer-status");
      if (status) {
        status.textContent = savingText || "";
        status.className = "poll-open-answer-status js-poll-open-answer-status -saving";
      }

      const answersWrapper = form.closest('[id$="_answers"]');
      if (answersWrapper) {
        const observer = new MutationObserver(() => {
          observer.disconnect();

          const newForm = answersWrapper.querySelector(".js-poll-open-answer-autosave");
          if (!newForm) return;

          const newTextarea = newForm.querySelector("textarea");
          if (newTextarea) {
            if (wasFocused) newTextarea.focus();
            try { newTextarea.setSelectionRange(selStart, selEnd); } catch (_) {}
          }

          const newStatus = newForm.querySelector(".js-poll-open-answer-status");
          if (newStatus) {
            newStatus.textContent = savedText || "";
            newStatus.className = "poll-open-answer-status js-poll-open-answer-status -saved";
            this.openAnswerStatusTimers.set(newForm, setTimeout(() => {
              newStatus.textContent = "";
              newStatus.className = "poll-open-answer-status js-poll-open-answer-status";
            }, 2000));
          }
        });
        observer.observe(answersWrapper, { childList: true, subtree: true });
      }

      $(form).one("ajax:error", () => {
        if (status) {
          status.textContent = errorText || "";
          status.className = "poll-open-answer-status js-poll-open-answer-status -error";
        }
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

      const containerWidth = $answersContainer.width();
      const parentWidth = $parentContainer.width();
      const vertical = containerWidth > parentWidth;
      console.log("[RS] formatRatingScale", {
        id: $element.closest("[id]").attr("id"),
        visible: $element.is(":visible"),
        containerWidth: containerWidth,
        parentWidth: parentWidth,
        decision: vertical ? "VERTICAL" : "horizontal"
      });

      if (vertical) {
        $element.addClass('vertical-rating-scale-answers');
      } else {
        $element.removeClass('vertical-rating-scale-answers');
      }
    },

    formatVisibleRatingScales: function() {
      const $scales = $(".js-rating-scale:visible");
      console.log("[RS] formatVisibleRatingScales — matched", $scales.length, "of", $(".js-rating-scale").length, "total");
      $scales.each(function() {
        App.PollsCustom.formatRatingScale(this);
      });
    },

    formatVisibleRatingScalesAfterRepaint: function() {
      console.trace("[RS] formatVisibleRatingScalesAfterRepaint (rAF scheduled)");
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
