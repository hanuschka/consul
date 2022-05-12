(function() {
  "use strict";
  App.ProjektQuestionCustom = {
    loadNextQuestion: function(href) {
      $.get(href).then(function(response) {
        $('.js-projekt-question-section').replaceWith(response)
      })
    },

    initialize: function() {
      $("body").on("click", ".js-projekt-question-next", function(e) {
        e.preventDefault()
        e.stopPropagation()
        this.loadNextQuestion(e.currentTarget.href)
      }.bind(this));

      $('body').on('ajax:success', '.js-projekt-answer-form', function(data) {
        this.loadNextQuestion($('.js-projekt-question-next').attr('href'))
      }.bind(this));
    }
  }
}).call(this);
