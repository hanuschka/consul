(function() {
  "use strict";

  App.QuestionWizard = {
    map: [],
    byId: {},
    indexById: {},
    hiddenIds: {},
    visited: [],
    inFlight: {},

    initialize() {
      const $wizard = $(".js-question-wizard");
      if ($wizard.length === 0) return;

      this.parseMap();
      this.hiddenIds = {};
      this.inFlight = {};
      this.visited = [];

      $wizard.off(".questionWizard");
      $("body").off("click.questionWizard");
      $wizard.on("click.questionWizard", ".js-question-wizard-prev", this.navigateToPrevQuestion.bind(this));
      $wizard.on("click.questionWizard", ".js-question-wizard-next", this.navigateToNextQuestion.bind(this));
      $wizard.on("click.questionWizard", ".js-question-wizard-go-to-start", this.goToStart.bind(this));
      $("body").on("click.questionWizard", ".js-poll-closing-note", this.showClosingNote.bind(this));

      const first = this.currentQuestion();
      if (!first) return;

      this.updateProgress(first);
      this.updateNavButtons();
      this.mandatoryQuestionActions();
    },

    parseMap() {
      const wizard = document.querySelector(".js-question-wizard");
      const serializedMap = wizard ? wizard.dataset.wizardMap : null;

      try {
        this.map = serializedMap ? JSON.parse(serializedMap) : [];
      } catch (error) {
        this.map = [];
      }

      this.byId = {};
      this.indexById = {};

      this.map.forEach((entry, index) => {
        this.byId[entry.id] = entry;
        this.indexById[entry.id] = index;
      });
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
      if (!current) return;

      const currentId = this.questionIdOf(current);
      this.applyContextHiding(currentId, current);

      const nextId = this.resolveNextId(currentId, current);

      if (!nextId) {
        this.updateNavButtons();
        return;
      }

      this.ensureLoaded(nextId, (node) => this.advanceTo(currentId, node));
    },

    advanceTo(fromId, node) {
      if (!node) {
        this.mandatoryQuestionActions();
        return;
      }

      this.visited.push(fromId);
      this.showNode(node);
      this.scrollToWizardTop();
    },

    navigateToPrevQuestion() {
      $("#closing-note").hide();
      if (this.visited.length === 0) return;

      const node = this.getQuestionNode(this.visited.pop());
      if (!node) return;

      this.showNode(node);
      this.scrollToWizardTop();
    },

    goToStart() {
      if (this.map.length === 0) return;

      const first = this.getQuestionNode(this.map[0].id);
      if (!first) return;

      this.visited = [];
      $("#closing-note").hide();
      this.showNode(first);
      this.scrollToWizardTop();
    },

    nextVisibleIdAfter(id) {
      for (let i = this.indexById[id] + 1; i < this.map.length; i++) {
        if (!this.hiddenIds[this.map[i].id]) return this.map[i].id;
      }

      return null;
    },

    resolveNextId(currentId, currentNode) {
      const answered = currentNode.querySelector(".js-question-answered[data-next-question-id]");
      if (answered && answered.dataset.nextQuestionId) {
        const branchId = parseInt(answered.dataset.nextQuestionId, 10);
        if (this.byId[branchId] && !this.hiddenIds[branchId]) return branchId;
      }

      return this.nextVisibleIdAfter(currentId);
    },

    applyContextHiding(currentId, currentNode) {
      const entry = this.byId[currentId];
      if (!entry || !entry.is_context_source) return;

      const sourceAnswerIds = {};
      const unselectedIds = {};
      currentNode.querySelectorAll(".js-question-answer").forEach((answer) => {
        const answerId = parseInt(answer.dataset.answerId, 10);
        sourceAnswerIds[answerId] = true;
        if (!answer.classList.contains("js-question-answered")) unselectedIds[answerId] = true;
      });

      this.map.forEach((candidate) => {
        if (!candidate.context_answer_id || !sourceAnswerIds[candidate.context_answer_id]) return;

        if (unselectedIds[candidate.context_answer_id]) this.hiddenIds[candidate.id] = true;
        else delete this.hiddenIds[candidate.id];
      });
    },

    ensureLoaded(id, callback) {
      const node = this.getQuestionNode(id);
      if (node) {
        callback(node);
        return;
      }

      if (this.inFlight[id]) return;

      const entry = this.byId[id];
      if (!entry || !entry.url) {
        callback(null);
        return;
      }

      this.inFlight[id] = true;
      this.nextButton().prop("disabled", true);

      App.Ajax
        .request({ method: "GET", url: entry.url, dataType: "html" })
        .done((html) => this.onQuestionFetched(id, html, callback))
        .fail(() => this.onFetchFailed(callback))
        .always(() => { delete this.inFlight[id]; });
    },

    onQuestionFetched(id, html, callback) {
      this.insertInOrder(id, html);
      callback(this.getQuestionNode(id));
    },

    onFetchFailed(callback) {
      alert("Die nächste Frage konnte nicht geladen werden. Bitte versuchen Sie es erneut.");
      callback(null);
    },

    insertInOrder(id, html) {
      const container = document.querySelector(".question-wizard--questions");
      if (!container || this.getQuestionNode(id)) return;

      const wrapper = document.createElement("div");
      wrapper.innerHTML = html.trim();
      const newNode = wrapper.firstElementChild;
      if (!newNode) return;

      const myIndex = this.indexById[id];
      const loaded = container.querySelectorAll(".js-question-wizard-item");
      let before = null;

      for (let i = 0; i < loaded.length; i++) {
        if (this.indexById[this.questionIdOf(loaded[i])] > myIndex) {
          before = loaded[i];
          break;
        }
      }

      if (before) container.insertBefore(newNode, before);
      else container.appendChild(newNode);
    },

    showNode(node) {
      const current = this.currentQuestion();
      if (current) current.classList.remove("-visible");

      node.classList.add("-visible");
      node.classList.remove("-disabled");

      this.updateProgress(node);
      this.updateNavButtons();
      this.mandatoryQuestionActions();
      this.formatRatingScales();
    },

    updateNavButtons() {
      const node = this.currentQuestion();
      if (!node) return;

      if (this.nextVisibleIdAfter(this.questionIdOf(node))) {
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

    updateProgress(node) {
      const total = this.map.length;
      if (total === 0) return;

      const number = this.indexById[this.questionIdOf(node)] + 1;
      const progressbarWidth = $(".js-question-wizard--progress").width();
      $(".js-question-wizard .js-question-wizard--progress-bar").css("width", progressbarWidth * (number / total));
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
