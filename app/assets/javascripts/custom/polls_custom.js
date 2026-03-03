(function() {
  "use strict";
  App.PollsCustom = {
    resizeDebounceTimer: null,

    initialize: function() {
      this.destroy();

      App.PollsCustom.showOpenAnswers();

      $("body").on("click.pollsCustom", ".js-show-open-answers", this.handleOpenAnswersToggle.bind(this));

      this.formatVisibleRatingScales();

      $("body").on(
        "click.pollsCustom",
        ".js-question-wizard-next, .js-question-wizard-prev, .js-question-wizard-go-to-start",
        this.formatVisibleRatingScalesAfterRepaint.bind(this)
      );

      if ($(".js-rating-scale").length > 0) {
        $(window).on("resize.pollsCustom", this.handleWindowResize);
      }
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

      if ($answersContainer.width() > $parentContainer.width()) {
        $element.addClass('vertical-rating-scale-answers');
      } else {
        $element.removeClass('vertical-rating-scale-answers');
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
