(function() {
  "use strict";

  // Which question follows which is the server's answer, not this file's. The order,
  // the contexted clones, the branching and the answer that ends a ballot all live in
  // Polls::BallotTraversalQuery, which the WhatsApp bot walks too; this used to carry
  // a map of the whole poll and work them out again from it, so every rule about
  // which questions a citizen is ever shown existed in two places.
  //
  // What is left here is presentation: which node is visible, where the citizen has
  // been, and how far along the bar sits.
  App.QuestionWizard = {
    questionIds: [],
    visited: [],
    step: 1,
    inFlight: false,

    initialize() {
      const $wizard = $(".js-question-wizard");
      const $body = $("body");

      $body.off("click.questionWizard");
      $body.on("click.questionWizard", ".js-poll-closing-note", this.showClosingNote.bind(this));

      if ($wizard.length === 0) return;

      this.parseQuestionIds();
      this.visited = [];
      this.step = 1;
      this.inFlight = false;

      $wizard.off(".questionWizard");
      $wizard.on("click.questionWizard", ".js-question-wizard-prev", this.navigateToPrevQuestion.bind(this));
      $wizard.on("click.questionWizard", ".js-question-wizard-next", this.navigateToNextQuestion.bind(this));
      $wizard.on("click.questionWizard", ".js-question-wizard-go-to-start", this.goToStart.bind(this));

      const first = this.currentQuestion();
      if (!first) return;

      this.updateProgress();
      this.updateNavButtons();
      this.mandatoryQuestionActions();
    },

    // The ids the citizen's path held when the page was rendered, for the progress
    // bar and for going back to the start. Not a traversal: branching can make the
    // real walk shorter and a revealed question is not in it at all, which is why
    // the bar is capped rather than trusted.
    parseQuestionIds() {
      const wizard = document.querySelector(".js-question-wizard");
      const serialized = wizard ? wizard.dataset.wizardQuestionIds : null;

      try {
        this.questionIds = serialized ? JSON.parse(serialized) : [];
      } catch (error) {
        this.questionIds = [];
      }
    },

    nextButton() { return $(".js-question-wizard-next"); },
    closingNoteButton() { return $(".js-poll-closing-note"); },
    prevButton() { return $(".js-question-wizard-prev"); },
    goToStartButton() { return $(".js-question-wizard-go-to-start"); },

    currentQuestion() {
      return document.querySelector(".js-question-wizard .js-question-wizard-item.-visible");
    },

    getQuestionNode(id) {
      return document.querySelector(".js-question-wizard .js-question-wizard-item[data-question-id='" + id + "']");
    },

    questionIdOf(node) {
      return parseInt(node.dataset.questionId, 10);
    },

    navigateToNextQuestion() {
      const current = this.currentQuestion();
      if (!current || this.inFlight) return;

      const url = current.dataset.nextUrl;
      if (!url) return;

      this.inFlight = true;
      this.nextButton().prop("disabled", true);

      App.Ajax
        .request({ method: "GET", url: url, dataType: "json" })
        .done((response) => this.advanceTo(this.questionIdOf(current), response))
        .fail(() => this.onFetchFailed())
        .always(() => { this.inFlight = false; });
    },

    // No question back means the ballot ends here — the last one on the path, or one
    // whose answer terminated it. The button changes to say so rather than the
    // citizen being left tapping a "next" that does nothing.
    advanceTo(fromId, response) {
      if (!response || !response.question_id) {
        this.setHasNext(fromId, false);
        return;
      }

      const node = this.getQuestionNode(response.question_id) ||
        this.insertQuestion(response.html);

      if (!node) {
        this.onFetchFailed();
        return;
      }

      node.dataset.hasNext = response.has_next ? "true" : "false";

      this.visited.push(fromId);
      this.step += 1;
      this.showNode(node);
      this.scrollToWizardTop();
    },

    // Appended rather than slotted into a configured order: the order is the order
    // the citizen was walked through, and that is the order they go back through.
    insertQuestion(html) {
      const container = document.querySelector(".question-wizard--questions");
      if (!container || !html) return null;

      const wrapper = document.createElement("div");
      wrapper.innerHTML = html.trim();
      const node = wrapper.firstElementChild;
      if (!node) return null;

      container.appendChild(node);
      return node;
    },

    // Called from polls/questions/answers.js.erb after every recorded answer,
    // because an answer is what can change it: it may branch, it may end the ballot,
    // and it may reveal a question contextualised by the option just chosen.
    setHasNext(questionId, hasNext) {
      const node = this.getQuestionNode(questionId);
      if (!node) return;

      node.dataset.hasNext = hasNext ? "true" : "false";
      this.updateNavButtons();
    },

    navigateToPrevQuestion() {
      $("#closing-note").hide();
      if (this.visited.length === 0) return;

      const node = this.getQuestionNode(this.visited.pop());
      if (!node) return;

      this.step = Math.max(1, this.step - 1);
      this.showNode(node);
      this.scrollToWizardTop();
    },

    goToStart() {
      if (this.questionIds.length === 0) return;

      const first = this.getQuestionNode(this.questionIds[0]);
      if (!first) return;

      this.visited = [];
      this.step = 1;
      $("#closing-note").hide();
      this.showNode(first);
      this.scrollToWizardTop();
    },

    refreshMaps(node) {
      if (!node || !node.querySelector("[data-map]")) return;

      App.Map.refreshMapsIn(node);
      App.PollMapPoints.initialize();
    },

    onFetchFailed() {
      alert("Die nächste Frage konnte nicht geladen werden. Bitte versuchen Sie es erneut.");
      this.mandatoryQuestionActions();
    },

    showNode(node) {
      const current = this.currentQuestion();
      if (current) current.classList.remove("-visible");

      node.classList.add("-visible");
      node.classList.remove("-disabled");

      this.updateProgress();
      this.updateNavButtons();
      this.mandatoryQuestionActions();
      this.formatRatingScales();
      this.refreshMaps(node);
    },

    updateNavButtons() {
      const node = this.currentQuestion();
      if (!node) return;

      if (node.dataset.hasNext === "true") {
        this.nextButton().show();
        this.closingNoteButton().hide();
      } else {
        this.nextButton().hide();
        this.closingNoteButton().show();
      }

      if (this.visited.length > 0) {
        this.prevButton().show();
        this.goToStartButton().show();
      } else {
        this.prevButton().hide();
        this.goToStartButton().hide();
      }
    },

    // Counted in steps taken rather than read off a position in a list: a branching
    // ballot skips questions, and a contextualised one adds a question the list
    // rendered with the page never held. Capped at full for the same reason — the
    // total is what the path held at load, so the walk can outrun it.
    updateProgress() {
      const total = this.questionIds.length;
      if (total === 0) return;

      const progressbarWidth = $(".js-question-wizard--progress").width();
      const share = Math.min(this.step / total, 1);
      $(".js-question-wizard .js-question-wizard--progress-bar").css("width", progressbarWidth * share);
    },

    mandatoryQuestionActions() {
      const $questionElement = $(this.currentQuestion()).find(".js-poll-question");
      const $nestedQuestions = $questionElement.find(".poll-question--nested-question");

      this.nextButton().prop("disabled", false);
      this.closingNoteButton().prop("disabled", false);

      if ($questionElement.data("answerMandatory") && $questionElement.find(".js-question-answered").length === 0) {
        this.nextButton().prop("disabled", true);
        this.closingNoteButton().prop("disabled", true);
      }

      $nestedQuestions.each((index, nestedQuestion) => {
        if ($(nestedQuestion).data("answerMandatory") && $(nestedQuestion).find(".js-question-answered").length === 0) {
          this.nextButton().prop("disabled", true);
          this.closingNoteButton().prop("disabled", true);
        }
      });
    },

    showClosingNote() {
      $(".poll-question").hide();
      $("#closing-note").show();
      this.closingNoteButton().hide();
      this.prevButton().hide();
      this.goToStartButton().hide();
      $(".js-question-wizard--progress").hide();
    },

    formatRatingScales() {
      if (App.PollsCustom && App.PollsCustom.formatVisibleRatingScalesAfterRepaint) {
        App.PollsCustom.formatVisibleRatingScalesAfterRepaint();
      }
    },

    scrollToWizardTop() {
      const wizardTop = $(".question-wizard").parent().offset().top - 100;
      $("html, body").animate({ scrollTop: wizardTop }, 500);
    }
  };
}).call(this);
