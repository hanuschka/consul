(function() {
  "use strict";
  App.ProjektQuestionCustom = {
    initialize: function() {
      $("body").on("click", ".js-projekt-question-new", function(e) {
        $(e.target.closest('.projekt-new-question-notification')).hide();
      }.bind(this));

      $('body').on('change', '.js-projekt-answer-form input', this.debounce(this.submitForm.bind(this), 500))
      $("body").on("ajax:error", ".js-projekt-answer-form", this.handleSubmitError.bind(this));
    },

    debounce: function(func, duration, immediate) {
      var timeout;

      return function() {
        var context = this, args = arguments;
        var later = function() {
          timeout = null;
          if (!immediate) func.apply(context, args);
        };
        var callNow = immediate && !timeout;

        clearTimeout(timeout);
        timeout = setTimeout(later, duration);

        if (callNow) func.apply(context, args);
      };
    },

    submitForm: function(e) {
      var $element = $(e.currentTarget)
      this.hideError($element.closest('form'));
      $element.closest('form').trigger('submit.rails')
      var $elementLabel = $element.parent('label')

      $elementLabel.parent().find('label input[type="radio"]').prop('disabled', true)

      $elementLabel.siblings('label').removeClass('is-active')
      $elementLabel.addClass('is-active')
      $(".js-projekt-question-section").addClass("show-loader");
    },

    handleSubmitError: function(e, xhr) {
      var $form = $(e.currentTarget);
      var $labels = $form.find(".projekt-question-answer-option");
      var $radios = $labels.find('input[type="radio"]');

      $(".js-projekt-question-section").removeClass("show-loader");
      $labels.removeClass("is-active");
      $radios.prop("checked", false);
      $labels.filter(".-active").find('input[type="radio"]').prop("checked", true);

      if (this.isClosedResponse(xhr)) {
        this.showError($form, $form.data("closed-message"));
      } else {
        $radios.prop("disabled", false);
        this.showError($form, $form.data("error-message"));
      }
    },

    isClosedResponse: function(xhr) {
      if (!xhr || xhr.status !== 422) return false;

      try {
        return JSON.parse(xhr.responseText).error === "closed";
      } catch (error) {
        return false;
      }
    },

    showError: function($form, message) {
      var $error = $form.find(".js-projekt-answer-error");

      $error.text("").addClass("is-visible");
      setTimeout(function() {
        $error.text(message);
      }, 100);
    },

    hideError: function($form) {
      $form.find(".js-projekt-answer-error").removeClass("is-visible").text("");
    }
  }
}).call(this);
