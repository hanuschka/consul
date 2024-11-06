(function() {
  "use strict";
  App.HTMLEditor = {
    initialize: function() {
      $("textarea.html-area").each(function() {
        if ($(this).hasClass("extended")) {
          CKKEDITOR.replace(this.name, { language: $("html").attr("lang"), toolbar: "extended", height: 500 });
        } else {
          CKKEDITOR.replace(this.name, { language: $("html").attr("lang") });
        }
      });
    },
    destroy: function() {
      for (var name in CKKEDITOR.instances) {
        CKKEDITOR.instances[name].destroy();
      }
    }
  };
}).call(this);
