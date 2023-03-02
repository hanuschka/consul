(function() {
  "use strict";
  App.TextSearchFormComponent = {
    initialize: function() {
      $(".js-text-search-form-reset-button").on("click", this.resetForm.bind(this));
      // $(".js-text-search-form").on("click", this.enableTurbolinksSubmit.bind(this));
    },

    resetForm: function(e) {
      var $parentForm = $(e.currentTarget).closest('form');
      var $searchText = $parentForm.find('#search_text');

      $searchText.val("").prop("disabled", true);
      $parentForm.submit();
    }
  };
}).call(this);
