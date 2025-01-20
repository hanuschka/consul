(function() {
  "use strict";
  App.IframeFilter = {
    blurIframes: function() {
      var expainerText = "<div class='iframe-explainer'><p class='iframe-explainer-text'>Mit dem Aufruf des Inhaltes erklären Sie sich einverstanden, dass Ihre Daten an Drittanbieter übermittelt werden und das Sie die Datenschutzerklärung gelesen haben.</p><a href='' class='js-iframe-consent-button iframe-consent-button'>Akzeptieren</a></div>"

      if ($('.admin-content iframe[src*="matomo"]').length > 0) {
        return false;
      }

      // $('iframe').each( function() {
      $('iframe').not('[name="votingFrame"], [sandbox="allow-scripts"]').each( function() {
        $(this).wrap( "<div class='iframe-wrapper'></div>" );
        $(this).after( expainerText )
      })
    },

    initialize: function() {
      var iframeMetaSetting = document.querySelector("meta[name='two-click-iframes']");

      if (iframeMetaSetting && iframeMetaSetting.getAttribute("content") === 'active' ) {
        App.IframeFilter.blurIframes();

        $("body").on("click", ".js-iframe-consent-button", function(event) {
          event.preventDefault();

          var $iframe = $(this).closest('.iframe-wrapper').find('iframe');
          $iframe.attr('src', $iframe.attr('data-src'));

          $(this).closest('.iframe-explainer').hide();
        });
      }
    }
  }
}).call(this);
