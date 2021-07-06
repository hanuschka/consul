(function() {
  "use strict";
  App.ElasticSearchModal = {
    initialize: function() {
      $("body").on("click", "#js-main-menu-search-button", function(event) {
        event.preventDefault();
        $('main').addClass("grayed-out");
        $('.elasticSearchModal').show();
        var $searchField = $("#navigation_bar .elasticSearchModal #search_text")
        $searchField.val('')
        $searchField.focus();
        return false;
      });

      $("body").on("click", "main.grayed-out", function(event) {
        $('main').removeClass("grayed-out");
        $('.elasticSearchModal').hide();
      })
    }
  }
}).call(this);
