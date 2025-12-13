(function() {
  App.GoogleTranslate = {
    loadScript() {
      // console.log("loadScript")
      const script = document.createElement('script');
      script.type = 'text/javascript';
      script.src = '//translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';
      document.head.appendChild(script);
    },

    initialize() {
      // console.log("App.GoogleTranslate.initialize")
      this.cleanExistingGoogleTranslate()

      if ($(".hamburger-menu:visible").length) {
        new google.translate.TranslateElement({pageLanguage: 'de'}, 'google_translate_element_mobile');
      } else {
        new google.translate.TranslateElement({pageLanguage: 'de'}, 'google_translate_element_desktop');
      }
    },

    cleanExistingGoogleTranslate() {
      $(".google_translate_element").empty()
    }
  };

  window.googleTranslateElementInit = function() {
    // console.log("googleTranslateElementInit")
    App.GoogleTranslate.initialize();
  };

  $(document).on('turbolinks:load', function() {
    if (!App.Features.isEnabled('google-translate-enabled')) {
      return;
    }

    // if (typeof google === 'undefined' || typeof google.translate === 'undefined') {
    // }
    App.GoogleTranslate.loadScript();
  });
}).call(this);
