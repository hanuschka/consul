$(document).on('turbolinks:load', function() {
  if (window.location.pathname == "/privacy") {
    var matomoExternalScript = document.createElement('script');
    matomoExternalScript.src = 'https://piwik.siegburg.eu/index.php?module=CoreAdminHome&action=optOutJS&divId=matomo-opt-out&language=auto&showIntro=1';
    document.head.appendChild(matomoExternalScript);
  }
});
