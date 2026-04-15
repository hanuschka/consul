(function() {
  "use strict";
  App.SocialShare = {
    initialize: function() {
      $(".social-share-button a").each(function() {
        if ($(this).find(".show-for-sr").length) return

        $(this).append("<span class='show-for-sr'>" + ($(this).data("site").replace(/_app$/, "")) + "</span>");
      });
    },
    destroy: function() {
      $(".social-share-button a .show-for-sr").remove();
    }
  };
}).call(this);
