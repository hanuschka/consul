(function() {
  "use strict";

  // One question per screen, mirroring how the Mitmachbox itself asks. The
  // whole survey is in the DOM; without JavaScript it stays a plain long form
  // and the platform drops the answers that lie off the run's path.
  App.MitmachboxSurvey = {
    initialize: function() {
      var $forms = $(".js-mitmachbox-survey-form");
      if (!$forms.length) return;

      $forms.each(function() {
        App.MitmachboxSurvey.setup($(this));
      });
    },

    setup: function($form) {
      var self = this;
      var state = { visited: [], current: 0 };

      if (!this.questions($form).length) return;

      // The wizard gates required questions itself; native validation would
      // block the submit on a question that is not on screen.
      $form.find("input[required]").prop("required", false);
      $form.find(".js-mitmachbox-progress, .js-mitmachbox-prev, .js-mitmachbox-next")
        .prop("hidden", false);

      $form.on("click", ".js-mitmachbox-next", function() {
        self.goNext($form, state);
      });

      $form.on("click", ".js-mitmachbox-prev", function() {
        self.goPrev($form, state);
      });

      $form.on("change", "input", function() {
        self.clearError($form);
        self.updateControls($form, state);
      });

      $form.on("submit", function(event) {
        if (!self.readyToSubmit($form, state)) {
          event.preventDefault();
          return;
        }

        self.disableOffPath($form);
      });

      this.showQuestion($form, state, 0, { focus: false });
    },

    questions: function($form) {
      return $form.find(".js-mitmachbox-question");
    },

    showQuestion: function($form, state, index, options) {
      var $questions = this.questions($form);

      state.current = index;
      $questions.prop("hidden", true);
      $questions.eq(index).prop("hidden", false);

      this.clearError($form);
      this.updateControls($form, state);

      if (options && options.focus === false) return;

      var $prompt = $questions.eq(index).find(".js-mitmachbox-question-prompt");
      $prompt.trigger("focus");
      this.scrollIntoView($questions.eq(index));
    },

    goNext: function($form, state) {
      if (!this.answered($form, state.current)) {
        this.showError($form);
        return;
      }

      var target = this.nextIndex($form, state.current);
      if (target < 0) return;

      state.visited.push(state.current);
      this.showQuestion($form, state, target);
    },

    goPrev: function($form, state) {
      if (!state.visited.length) return;

      this.showQuestion($form, state, state.visited.pop());
    },

    // The last question of the run gets the submit button instead of "next" —
    // an option that ends the survey makes its own question the last one.
    updateControls: function($form, state) {
      var last = this.nextIndex($form, state.current) < 0;

      $form.find(".js-mitmachbox-prev").prop("hidden", !state.visited.length);
      $form.find(".js-mitmachbox-next").prop("hidden", last);
      $form.find(".js-mitmachbox-submit").prop("hidden", !last);

      this.updateProgress($form, state);
    },

    updateProgress: function($form, state) {
      var step = state.visited.length + 1;
      var total = Math.max(this.reachedIds(this.questions($form)).length, step);
      var $label = $form.find(".js-mitmachbox-progress-label");

      $label.text($label.data("template").replace("{current}", step).replace("{total}", total));
      $form.find(".js-mitmachbox-progress-bar").css("width", (100 * step / total) + "%");
    },

    answered: function($form, index) {
      var $question = this.questions($form).eq(index);
      if (!$question.data("required")) return true;

      return $question.find("input:checked").length > 0;
    },

    // Nothing may be submitted while a required question on the path is still
    // unanswered — reachable by pressing Enter rather than the button.
    readyToSubmit: function($form, state) {
      var $questions = this.questions($form);
      var reached = this.reachedIds($questions);
      var missing = -1;

      $questions.each(function(index) {
        if (missing >= 0) return;
        if (reached.indexOf($(this).data("question-id")) === -1) return;
        if (!App.MitmachboxSurvey.answered($form, index)) missing = index;
      });

      if (missing < 0) return true;

      this.showQuestion($form, state, missing);
      this.showError($form);
      return false;
    },

    disableOffPath: function($form) {
      var $questions = this.questions($form);
      var reached = this.reachedIds($questions);

      $questions.each(function() {
        var $question = $(this);
        var onPath = reached.indexOf($question.data("question-id")) !== -1;

        $question.find("input").prop("disabled", !onPath);
      });
    },

    // Where the current answer leads: the index of the follow-up question, or
    // -1 when the run ends here.
    nextIndex: function($form, index) {
      var $questions = this.questions($form);
      var $chosen = $questions.eq(index).find("input[type=radio]:checked");

      if ($chosen.length === 1) {
        if ($chosen.data("ends-survey")) return -1;

        var next = $chosen.data("next-question-id");
        if (next) {
          var target = this.indexOfQuestion($questions, next);
          return target > index ? target : -1;
        }
      }

      return index + 1 < $questions.length ? index + 1 : -1;
    },

    reachedIds: function($questions) {
      var reached = [];
      var index = 0;

      while (index < $questions.length) {
        var $question = $questions.eq(index);
        reached.push($question.data("question-id"));

        var $chosen = $question.find("input[type=radio]:checked");
        if ($chosen.length !== 1) {
          index++;
          continue;
        }
        if ($chosen.data("ends-survey")) break;

        var next = $chosen.data("next-question-id");
        if (!next) {
          index++;
          continue;
        }

        var target = this.indexOfQuestion($questions, next);
        if (target <= index) break;

        index = target;
      }

      return reached;
    },

    indexOfQuestion: function($questions, questionId) {
      var found = -1;

      $questions.each(function(index) {
        if ($(this).data("question-id") === questionId) found = index;
      });

      return found;
    },

    showError: function($form) {
      var $error = $form.find(".js-mitmachbox-error");

      $error.text($error.data("message")).prop("hidden", false);
    },

    clearError: function($form) {
      $form.find(".js-mitmachbox-error").prop("hidden", true).text("");
    },

    scrollIntoView: function($question) {
      var top = $question.offset().top - 100;

      $("html, body").animate({ scrollTop: top }, 300);
    }
  };
}).call(this);
