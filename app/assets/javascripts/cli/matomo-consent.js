$(document).on('turbolinks:load', function() {
  if (window.location.pathname == "/matomo-consent") {
    var matomoExternalScript = document.createElement('script');
    matomoExternalScript.src = "https://unsereheimatgestalten.matomo.cloud/index.php?module=CoreAdminHome&action=optOutJS&divId=matomo-opt-out&language=auto&showIntro=1";
    document.head.appendChild(matomoExternalScript);
  }
});