// By default, Klaro will load the config from  a global "klaroConfig" variable.
// You can change this by specifying the "data-config" attribute on your
// script take, e.g. like this:
// <script src="klaro.js" data-config="myConfigVariableName" />
var klaroConfig = {
    // With the 0.7.0 release we introduce a 'version' paramter that will make
    // it easier for us to keep configuration files backwards-compatible in the future.
    version: 1,

    // You can customize the ID of the DIV element that Klaro will create
    // when starting up. If undefined, Klaro will use 'klaro'.
    elementID: 'klaro',

    // You can override CSS style variables here. For IE11, Klaro will
    // dynamically inject the variables into the CSS. If you still consider
    // supporting IE9-10 (which you probably shouldn't) you need to use Klaro
    // with an external stylesheet as the dynamic replacement won't work there.
    styling: {
        theme: ['light', 'top', 'wide'],
    },

    // Setting this to true will keep Klaro from automatically loading itself
    // when the page is being loaded.
    noAutoLoad: false,

    // Setting this to true will render the descriptions of the consent
    // modal and consent notice are HTML. Use with care.
    htmlTexts: true,

    // Setting 'embedded' to true will render the Klaro modal and notice without
    // the modal background, allowing you to e.g. embed them into a specific element
    // of your website, such as your privacy notice.
    embedded: false,

    // You can group services by their purpose in the modal. This is advisable
    // if you have a large number of services. Users can then enable or disable
    // entire groups of services instead of having to enable or disable every service.
    groupByPurpose: true,

    // How Klaro should store the user's preferences. It can be either 'cookie'
    // (the default) or 'localStorage'.
    storageMethod: 'cookie',

    // You can customize the name of the cookie that Klaro uses for storing
    // user consent decisions. If undefined, Klaro will use 'klaro'.
    cookieName: 'klaro',

    // You can also set a custom expiration time for the Klaro cookie.
    // By default, it will expire after 120 days.
    cookieExpiresAfterDays: 365,

    // You can change to cookie domain for the consent manager itself.
    // Use this if you want to get consent once for multiple matching domains.
    // If undefined, Klaro will use the current domain.
    //cookieDomain: '.github.com',

    // You can change to cookie path for the consent manager itself.
    // Use this to restrict the cookie visibility to a specific path.
    // If undefined, Klaro will use '/' as cookie path.
    //cookiePath: '/',

    // Defines the default state for services (true=enabled by default).
    default: false,

    // If "mustConsent" is set to true, Klaro will directly display the consent
    // manager modal and not allow the user to close it before having actively
    // consented or declines the use of third-party services.
    mustConsent: false,

    // Show "accept all" to accept all services instead of "ok" that only accepts
    // required and "default: true" services
    acceptAll: true,

    // replace "decline" with cookie manager modal
    hideDeclineAll: true,

    // hide "learnMore" link
    hideLearnMore: false,

    // show cookie notice as modal
    noticeAsModal: true,

    // You can also remove the 'Realized with Klaro!' text in the consent modal.
    // Please don't do this! We provide Klaro as a free open source tool.
    // Placing a link to our website helps us spread the word about it,
    // which ultimately enables us to make Klaro! better for everyone.
    // So please be fair and keep the link enabled. Thanks :)
    //disablePoweredBy: true,

    // you can specify an additional class (or classes) that will be added to the Klaro `div`
    //additionalClass: 'my-klaro',

    // You can define the UI language directly here. If undefined, Klaro will
    // use the value given in the global "lang" variable. If that does
    // not exist, it will use the value given in the "lang" attribute of your
    // HTML tag. If that also doesn't exist, it will use 'en'.
    //lang: 'en',

    // You can overwrite existing translations and add translations for your
    // service descriptions and purposes. See `src/translations/` for a full
    // list of translations that can be overwritten:
    // https://github.com/KIProtect/klaro/tree/master/src/translations

    // Example config that shows how to overwrite translations:
    // https://github.com/KIProtect/klaro/blob/master/src/configs/i18n.js
    translations: {
        // translationsed defined under the 'zz' language code act as default
        // translations.
        zz: {
            privacyPolicyUrl: '/#privacy',
        },
        // If you erase the "consentModal" translations, Klaro will use the
        // bundled translations.
        de: {
            ok: 'Alle akzeptieren',
            consentNotice: {
              description: 'Wir speichern und verarbeiten Ihre personenbezogenen Informationen für folgende Zwecke: {purposes}',
              learnMore: 'Individuelle Datenschutzeinstellungen'
            },
            privacyPolicyUrl: '/#datenschutz',
            consentModal: {
                title: 'Datenschutzeinstellungen',
                description: 'Wir nutzen Cookies auf unserer Website. Einige von ihnen sind essenziell, während andere uns helfen, diese Website und Ihre Erfahrung zu verbessern. Hier können Sie einsehen und anpassen, welche Information wir mit Hilfe dieser Cookies sammeln. Um mehr zu erfahren, lesen Sie bitte unsere Datenschutzerklärung.'
            },
            consul_ahoy: {
              title: 'Eingebauter Besucherzähler'
            },
            matomo: {
                description: 'Sammeln von Besucherstatistiken',
            },
            purposes: {
                analytics: 'Statistiken',
                security: 'Sicherheit',
                livechat: 'Live Chat',
                advertising: 'Anzeigen von Werbung',
                styling: 'Styling',
                essential: 'Essenziell'
            },
        },
        en: {
            ok: 'Accept all',
            consentNotice: {
              description: 'We save and proces your personal information for the following purposes: {purposes}',
              learnMore: 'Individual data protection settings'
            },
            privacyPolicyUrl: '/#datenschutz',
            consentModal: {
                title: 'Data protection settings',
                description: 'Here you can see and customize the information that we collect about you. Entries marked as "Example" are just for demonstration purposes and are not really used on this website.',
            },
            consul_ahoy: {
              title: 'Built-in visitor counter'
            },
            matomo: {
                description: 'Collecting of visitor statistics',
            },
            purposes: {
                analytics: 'Analytics',
                security: 'Security',
                livechat: 'Livechat',
                advertising: 'Advertising',
                styling: 'Styling',
                essential: 'Essential'
            },
        },
    },

    // This is a list of third-party services that Klaro will manage for you.
    services: [
        {
            name: 'consul_ahoy',
            default: true,
            purposes: ['essential'],
            required: true
        },
        // {
        //     name: 'matomo',
        //     default: true,
        //     title: 'Matomo/Piwik',
        //     purposes: ['analytics'],
        //     cookies: [
        //         [/^_pk_.*$/, '/', 'klaro.kiprotect.com'], //for the production version
        //         [/^_pk_.*$/, '/', 'localhost'], //for the local version
        //         'piwik_ignore',
        //     ],

        //     // An optional callback function that will be called each time
        //     // the consent state for the service changes (true=consented). Passes
        //     // the `service` config as the second parameter as well.
        //     callback: function(consent, service) {
        //         // This is an example callback function.
        //         console.log(
        //             'User consent for service ' + service.name + ': consent=' + consent
        //         );
        //         // To be used in conjunction with Matomo 'requireCookieConsent' Feature, Matomo 3.14.0 or newer
        //         // For further Information see https://matomo.org/faq/new-to-piwik/how-can-i-still-track-a-visitor-without-cookies-even-if-they-decline-the-cookie-consent/
        //         /*
        //         if(consent==true){
        //             _paq.push(['rememberCookieConsentGiven']);
        //         } else {
        //             _paq.push(['forgetCookieConsentGiven']);
        //         }
        //         */
        //     },

        //     required: false,
        //     optOut: false,
        //     onlyOnce: true,
        // },
        {
            name: 'youtube',
            default: true,
            purposes: ['marketing'],
        },
    ]
};
