(function() {
  "use strict";
  App.QuestionWizard = {
    initialize: function() {
      App.QuestionWizard.mandatoryQuestionActions();

      var $questionWizard = $(".js-question-wizard");

      $questionWizard.on("click", ".js-question-wizard-prev", this.navigateToPrevQuestion.bind(this));
      $questionWizard.on("click", ".js-question-wizard-next", this.navigateToNextQuestion.bind(this));
      $questionWizard.on("click", ".js-question-wizard-go-to-start", this.goToStart.bind(this));

      if ($questionWizard.length > 0) {
        this.updateProgress($questionWizard.find(".js-question-wizard-item").get(0));
      }

      $("body").on("click", ".js-poll-closing-note", this.showClosingNote.bind(this));
    },

    mandatoryQuestionActions: function() {
      var $questionElement = $(this.currentQuestion()).find(".js-poll-question");
      var $nestedQuestions = $questionElement.find(".poll-question--nested-question");

      $(".js-question-wizard-next").prop("disabled", false);

      if ($questionElement.data("answerMandatory") && $questionElement.find(".js-question-answered").length === 0) {
        $(".js-question-wizard-next").prop("disabled", true);
      }

      if ($nestedQuestions.length > 0) {
        $nestedQuestions.each(function(index, nestedQuestion) {
          if ( $(nestedQuestion).data("answerMandatory") && $(nestedQuestion).find(".js-question-answered").length === 0 ) {
            $(".js-question-wizard-next").prop("disabled", true);
          }
        });
      }
    },

    currentQuestion: function() {
      return document.querySelector(".js-question-wizard .js-question-wizard-item.-visible");
    },

    getQuestionById: function(id) {
      return document.querySelector(
        ".js-question-wizard [data-question-id='" + id + "']"
      );
    },

    navigateToQuestionById: function(id) {
      var question = this.getQuestionById(id);
      this.navigateToQuestion(question);
      this.scrollToWizardTop();
    },

    navigateToPrevQuestion: function() {
      $("#closing-note").hide();
      var prevQuestion = $(this.currentQuestion()).prevAll(".js-question-wizard-item:not(.-disabled)").get(0);

      this.navigateToQuestion(prevQuestion);
      this.scrollToWizardTop();
    },

    navigateToNextQuestion: function() {
      var currentQuestion = this.currentQuestion();
      var alreadyAnsweredOption = document.querySelector(
        ".js-question-wizard-item.-visible .js-question-answered"
      );
      var nextQuestion;

      if (alreadyAnsweredOption && alreadyAnsweredOption.dataset.nextQuestionId) {
        nextQuestion = this.getQuestionById(alreadyAnsweredOption.dataset.nextQuestionId);
      }
      else if (currentQuestion.dataset.nextQuestionId) {
        nextQuestion = this.getQuestionById(currentQuestion.dataset.nextQuestionId);
      } else {
        nextQuestion = currentQuestion.nextElementSibling;
      }

      this.markQuestionsAsDisabledBetween(currentQuestion, nextQuestion);
      this.navigateToQuestion(nextQuestion);
      this.scrollToWizardTop();
    },

    markQuestionsAsDisabledBetween: function(currentQuestion, nextQuestion) {
      $(currentQuestion).nextUntil(nextQuestion).addClass("-disabled");
    },

    firstQuestion: function() {
      return document.querySelector(".js-question-wizard .js-question-wizard-item:first-child");
    },

    goToStart: function() {
      var nextQuestion = this.firstQuestion();

      this.navigateToQuestion(nextQuestion);
      this.scrollToWizardTop();
    },

    showClosingNote: function() {
      $(".poll-question").hide();
      $("#closing-note").show();
      $(".js-poll-closing-note").hide();
      $(".js-question-wizard-prev").hide();
      $(".js-question-wizard-go-to-start").hide();
      $(".js-question-wizard--progress").hide();
    },

    navigateToQuestion: function(nextQuestion) {
      if (nextQuestion) {
        this.currentQuestion().classList.remove("-visible");
        nextQuestion.classList.add("-visible");
        nextQuestion.classList.remove("-disabled");

        // $(".js-question-wizard--progress-current-page").text(nextQuestion.dataset.questionNumber);
        this.updateProgress(nextQuestion);

        var $nextButton = $(".js-question-wizard-next");
        var $closingNoteButton = $(".js-poll-closing-note");

        if (nextQuestion.nextElementSibling) {
          $nextButton.show();
          $closingNoteButton.hide();
        } else {
          $nextButton.hide();
          $closingNoteButton.show();
        }

        var $previousButton = $(".js-question-wizard-prev");
        if (nextQuestion.previousElementSibling) {
          $previousButton.show();
        } else {
          $previousButton.hide();
        }
      }

      if (this.firstQuestion() === nextQuestion) {
        $(".js-question-wizard-go-to-start").hide();
      } else {
        $(".js-question-wizard-go-to-start").show();
      }

      App.QuestionWizard.mandatoryQuestionActions();
    },

    updateProgress: function(nextQuestion) {
      var totalQuestionsCount = $(".js-question-wizard-item").length;
      var progressbarWidth = $(".js-question-wizard--progress").width();
      var width = progressbarWidth * (nextQuestion.dataset.questionNumber / totalQuestionsCount);
      $(".js-question-wizard .js-question-wizard--progress-bar").css("width", width);
    },

    scrollToWizardTop: function() {
      var $questionWizardWrapper = $(".question-wizard").parent();
      var wizardTop = $questionWizardWrapper.offset().top - 100;

      $("html, body").animate({ scrollTop: wizardTop }, 500);
    }
  };
}).call(this);
