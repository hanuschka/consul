(function() {
  "use strict";

  App.RecipientGroups = {
    selectKind: function(selector) {
      App.RecipientGroups.clearSubsequentSelectors(selector);
      $(selector).closest('form').trigger('submit.rails');
    },

    clearSubsequentSelectors: function(selector) {
      $("#access_methods").remove();
      $(selector).closest('.recipient-group-options-for-kind').nextAll('.recipient-group-options-for-kind'). remove();
    },

    initialize: function() {
      $("body").on("click", ".js-select-recipient-group-kind", function(event) {
        App.RecipientGroups.selectKind(event.target);
      });
    }
  };
}).call(this);
