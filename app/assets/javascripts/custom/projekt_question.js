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

      $('body').on('change', '.js-project-question-list form input', function(e) {
        var $element = $(e.currentTarget)

        $element.closest('form').trigger('submit.rails')

        var $elementLabel = $element.parent('label')

        $elementLabel.siblings('label').removeClass('is-active')
        $elementLabel.addClass('is-active')
      })
    }
  }
}).call(this);
