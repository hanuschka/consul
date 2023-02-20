(function() {
  "use strict";
  App.HTMLEditor = {
    initialize: function() {
      this.enableCustomCkeditorStyles();

      $("textarea.html-area").each(function(_, element) {
        App.HTMLEditor.enableCKeditorFor(element);
      });
    },

    enableCKeditorFor: function(element) {
      if ($(element).hasClass("extended-u")) {
        var replaceBy = element.name;
        var toolbar = "extended_user";
        var height = 500;

      } else if ($(element).hasClass("extended-a")) {
        var replaceBy = element.id;
        var toolbar = "extended_admin";
        var height = 500;

      } else {
        var replaceBy = element.name;
      }

      var language = $("html").attr("lang");

      CKEDITOR.replace(replaceBy, {
        language: language,
        toolbar: toolbar,
        height: height,
        placeholdertext: element.placeholder
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
