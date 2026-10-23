(function() {
  "use strict";

  App.MapboxLoader = {
    load: function(callback) {
      if (window.mapboxgl) {
        callback();
        return;
      }

      window._mapboxMapQueue = window._mapboxMapQueue || [];
      window._mapboxMapQueue.push(callback);

      if (window._mapboxScriptsLoading) return;
      window._mapboxScriptsLoading = true;

      const cssUrls = [window.VendorAssetUrls.mapboxCss];
      cssUrls.forEach(url => {
        if (!document.querySelector(`link[href="${url}"]`)) {
          const link = document.createElement('link');
          link.rel = 'stylesheet';
          link.href = url;
          document.head.appendChild(link);
        }
      });

      const jsUrls = [window.VendorAssetUrls.mapboxJs];

      function loadNext(index) {
        if (index >= jsUrls.length) {
          window._mapboxMapQueue.forEach(function(initFn) { initFn(); });
          window._mapboxMapQueue = [];
          return;
        }

        const script = document.createElement('script');
        script.src = jsUrls[index];
        script.async = false; // preserve order
        script.onload = function() { loadNext(index + 1); };
        document.head.appendChild(script);
      }

      loadNext(0);
    }
  };
}).call(this);
