// GLightbox defaults to cdn.plyr.io for the player it loads on a video
// slide, and Plyr in turn defaults to the same host for its icon sprite and
// for the blank video it swaps in when cancelling requests. Every GLightbox
// instance must therefore pass these options, so they live here rather than
// at each call site: this file ships in elements.js, which both the main app
// and the /adm pack load.

(function() {
  "use strict";

  window.App = window.App || {};

  App.GlightboxPlyrOptions = function() {
    var urls = window.VendorAssetUrls || {};

    return {
      css: urls.plyrCss,
      js: urls.plyrJs,
      config: {
        iconUrl: urls.plyrIconSprite,
        blankVideo: urls.plyrBlankVideo
      }
    };
  };
}).call(this);
