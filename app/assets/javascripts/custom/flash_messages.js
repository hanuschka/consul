(function() {
  "use strict";
  App.FlashMessages = {
    ANNOUNCEMENT_DELAY: 100,
    FOCUS_DELAY: 600,

    initialize: function() {
      var $flashMessages = $(".js-flash-message");

      if (!$flashMessages.length) return;

      setTimeout(function() {
        App.FlashMessages.injectMessages($flashMessages);
      }, this.ANNOUNCEMENT_DELAY);
    },

    injectMessages: function($flashMessages) {
      var $liveRegion = $(".js-flash-live-region");
      var announcements = [];

      $flashMessages.each(function() {
        var $container = $(this);
        var text = $container.data("flash-text");
        var $noticeText = $container.find(".notice-text");

        $noticeText.html(text);
        announcements.push(text);
      });

      $liveRegion.html(announcements.join(". "));

      setTimeout(function() {
        var $firstNotice = $flashMessages.first().find(".notice-text");
        $firstNotice.focus();
      }, App.FlashMessages.FOCUS_DELAY);
    }
  };
}).call(this);
