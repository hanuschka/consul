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
      var state = { visited: [], current: 0, survey: this.survey(this.questions($form)) };

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

      var first = this.indexOfQuestion(this.questions($form), this.reachedIds(this.questions($form))[0]);

      this.showQuestion($form, state, Math.max(first, 0), { focus: false });
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

    // As on the box, the total is only shown when every path still possible
    // from here has the same length, so it never has to be corrected. The bar
    // measures against the longest path and so never moves backwards.
    updateProgress: function($form, state) {
      var step = state.visited.length + 1;
      var answered = this.visitedOptionIds($form, state);
      var range = this.pathRange(state.survey, state.current, answered, { left: 20000 });
      var $label = $form.find(".js-mitmachbox-progress-label");
      var $bar = $form.find(".js-mitmachbox-progress-bar");

      if (range && range.min === range.max) {
        var total = step - 1 + range.max;

        $label.text($label.data("template").replace("{current}", step).replace("{total}", total));
      } else {
        $label.text($label.data("template-open").replace("{current}", step));
      }

      $bar.closest(".progress").prop("hidden", !range);
      if (range) $bar.css("width", (100 * step / (step - 1 + range.max)) + "%");
    },

    survey: function($questions) {
      var survey = { questions: [], indexById: {}, conditionOptionIds: [] };

      $questions.each(function(index) {
        var $question = $(this);
        var question = {
          id: $question.data("question-id"),
          required: !!$question.data("required"),
          conditionOptionIds: $question.data("condition-option-ids") || [],
          options: $question.find("input[type=radio]").map(function() {
            return {
              id: Number($(this).val()),
              nextQuestionId: $(this).data("next-question-id"),
              endsSurvey: !!$(this).data("ends-survey")
            };
          }).get()
        };

        survey.questions.push(question);
        survey.indexById[question.id] = index;
        survey.conditionOptionIds = survey.conditionOptionIds.concat(question.conditionOptionIds);
      });

      return survey;
    },

    // Answers of the questions already passed; the current one is still open.
    visitedOptionIds: function($form, state) {
      var $questions = this.questions($form);

      return $.map(state.visited, function(index) {
        return $questions.eq(index).find("input:checked").map(function() {
          return Number($(this).val());
        }).get();
      });
    },

    // Shortest and longest number of questions from index on, over every
    // answer still possible (Mitmachbox::SurveyPath#path_range). Only
    // single-choice answers branch, and only those a condition refers to are
    // carried along. Null once the budget is used up.
    pathRange: function(survey, index, optionIds, budget) {
      if (index >= survey.questions.length) return { min: 0, max: 0 };
      if (budget.left === 0) return null;

      budget.left--;

      var self = this;
      var question = survey.questions[index];
      var min = Infinity;
      var max = 0;
      var seen = [];

      var visit = function(target, optionId) {
        var key = target + ":" + optionId;
        if (seen.indexOf(key) !== -1) return true;

        seen.push(key);

        var followed = optionId ? optionIds.concat([optionId]) : optionIds;
        var range = self.pathRange(survey, self.skipHidden(survey, target, followed), followed, budget);
        if (!range) return false;

        min = Math.min(min, range.min);
        max = Math.max(max, range.max);
        return true;
      };

      if (question.options.length) {
        for (var i = 0; i < question.options.length; i++) {
          var option = question.options[i];
          var carried = survey.conditionOptionIds.indexOf(option.id) !== -1 ? option.id : null;

          if (!visit(this.branchTarget(survey, index, option), carried)) return null;
        }
        if (!question.required && !visit(index + 1, null)) return null;
      } else if (!visit(index + 1, null)) {
        return null;
      }

      return { min: 1 + min, max: 1 + max };
    },

    branchTarget: function(survey, index, option) {
      if (option.endsSurvey) return survey.questions.length;
      if (!option.nextQuestionId) return index + 1;

      var target = survey.indexById[option.nextQuestionId];
      return target > index ? target : survey.questions.length;
    },

    skipHidden: function(survey, index, optionIds) {
      var target = index;

      while (target < survey.questions.length && !this.conditionMetBy(survey.questions[target], optionIds)) {
        target++;
      }

      return target;
    },

    conditionMetBy: function(question, optionIds) {
      if (!question.conditionOptionIds.length) return true;

      return question.conditionOptionIds.some(function(optionId) {
        return optionIds.indexOf(optionId) !== -1;
      });
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
      var next = -1;

      $.each(this.reachedIds($questions), function(_, questionId) {
        var candidate = App.MitmachboxSurvey.indexOfQuestion($questions, questionId);

        if (next < 0 && candidate > index) next = candidate;
      });

      return next;
    },

    reachedIds: function($questions) {
      var reached = [];
      var index = 0;

      while (index < $questions.length) {
        var $question = $questions.eq(index);

        if (!this.conditionMet($questions, $question, reached)) {
          index++;
          continue;
        }

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

    conditionMet: function($questions, $question, reached) {
      var optionIds = $question.data("condition-option-ids");
      if (!optionIds || !optionIds.length) return true;

      var sourceId = $question.data("condition-question-id");
      if (reached.indexOf(sourceId) === -1) return false;

      var chosen = $questions.eq(this.indexOfQuestion($questions, sourceId)).find("input:checked").map(function() {
        return Number($(this).val());
      }).get();

      return chosen.some(function(optionId) {
        return optionIds.indexOf(optionId) !== -1;
      });
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
