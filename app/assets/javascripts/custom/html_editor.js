(function() {
  "use strict";
  App.HTMLEditor = {
    initialize: function() {
      this.enableCustomCkeditorStyles();

      $("textarea.html-area").each(function(index, element) {
        if ($(this).hasClass("extended-u")) {
          var replaceBy = this.name;
          var toolbar = "extended_user";
          var height = 500;

        } else if ($(this).hasClass("extended-a")) {
          var replaceBy = this.id;
          var toolbar = "extended_admin";
          var height = 500;

        } else {
          var replaceBy = this.name;
        }

        var language = $("html").attr("lang");
        var placeholder = element.placeholder;

        CKEDITOR.replace(replaceBy, {
          language: language,
          toolbar: toolbar,
          height: height,
          placeholdertext: placeholder
        });
      });
    },

    enableCustomCkeditorStyles: function() {
      if ($(document.body).hasClass('new-custom-design')) {
        CKEDITOR.addCss(".cke_editable{font-size: 16px; } ");
      }
    },

    destroy: function() {
      for (var name in CKEDITOR.instances) {
        CKEDITOR.instances[name].destroy();
      }
    }
  };
}).call(this);
