(function() {
  "use strict";
  App.IframeFilter = {
    blurIframes: function() {
      var iframeMetaSetting = document.querySelector("meta[name='two-click-iframes']");

      if (!iframeMetaSetting || iframeMetaSetting.getAttribute("content") !== "true") return;

      const explainerText = iframeMetaSetting.dataset.explainerText;
      const consentButtonLabel = iframeMetaSetting.dataset.consentButton;

      if ($('.admin-content iframe[src*="matomo"]').length > 0) {
        return false;
      }

      // $('iframe').each( function() {
      $('iframe').not('[name="votingFrame"], [sandbox="allow-scripts"], .js-iframe-dont-render-overlay-note').each( function() {
        var $iframe = $(this);

        if ($iframe.parent('.iframe-wrapper').length > 0) return;

        $iframe.wrap( "<div class='iframe-wrapper js-iframe-consent-wrapper'></div>" );
        $iframe.after(App.IframeFilter.buildExplainer(explainerText, consentButtonLabel));
      })
    },

    buildExplainer: function(explainerText, consentButtonLabel) {
      const $text = $("<p class='iframe-explainer-text'></p>").text(explainerText);
      const $consentButton = $("<a href='' class='js-iframe-consent-button iframe-consent-button'></a>")
        .text(consentButtonLabel);

      return $("<div class='iframe-explainer js-iframe-consent-explainer'></div>").append($text, $consentButton);
    },

    initialize: function() {
      var iframeMetaSetting = document.querySelector("meta[name='two-click-iframes']");

      if (iframeMetaSetting && iframeMetaSetting.getAttribute("content") === 'true' ) {
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
