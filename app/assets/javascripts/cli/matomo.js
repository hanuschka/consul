var _paq = window._paq = window._paq || [];
/* tracker methods like "setCustomDimension" should be called before "trackPageView" */
_paq.push(["setDoNotTrack", true]);
// _paq.push(['disableCookies']);
_paq.push(['trackPageView']);
_paq.push(['enableLinkTracking']);

(function() {
  var u="https://webanalyse.jena.de/";
  var previousPageUrl = null;

  if (JSON.parse(App.Cookies.getCookie('klaro')).matomo == true) {
    addEventListener('turbolinks:load', function(event) {
      if (previousPageUrl) {
        _paq.push(['setReferrerUrl', previousPageUrl]);
        _paq.push(['setCustomUrl', window.location.href]);
        _paq.push(['setDocumentTitle', document.title]);
        _paq.push(['trackPageView']);
      }

      previousPageUrl = window.location.href;
    });

    _paq.push(['setTrackerUrl', u+'matomo.php']);
    _paq.push(['setSiteId', '125']);

    var d=document, g=d.createElement('script'), s=d.getElementsByTagName('script')[0];
    g.async=true; g.src=u+'matomo.js'; s.parentNode.insertBefore(g,s);
  }
})();
