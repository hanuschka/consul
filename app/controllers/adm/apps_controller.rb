module Adm
  class AppsController < Adm::BaseController
    APP_CATALOG = [
      {
        category: "Registrierung",
        icon: "person_add",
        apps: [
          { logo: "adm/apps/logo_facebook.png",          icon: "thumb_up",        name: "Facebook Login",    description: "Registrierung und Anmeldung über einen bestehenden Facebook-Account." },
          { logo: "adm/apps/logo_google.png",            icon: "search",          name: "Google Login",      description: "Registrierung und Anmeldung über einen bestehenden Google-Account." },
          { logo: "adm/apps/logo_x.png",                 icon: "tag",             name: "X Login",           description: "Registrierung und Anmeldung über einen bestehenden X (Twitter)-Account." },
          { logo: "adm/apps/logo_wordpress.png",         icon: "rss_feed",        name: "WordPress Login",   description: "Single Sign-On für Portale mit bestehendem WordPress-Nutzerstamm." }
        ]
      },
      {
        category: "Verifizierung",
        icon: "verified_user",
        apps: [
          { logo: "adm/apps/logo_bundid.png",            icon: "shield_person",   name: "BundID",               description: "Identitätsprüfung über das bundesweite Online-Bürgerkonto BundID – kompatibel mit eID und Nutzerkonto Bund." },
          { logo: "adm/apps/logo_bayernid.png",          icon: "shield_person",   name: "BayernID",             description: "Identitätsprüfung über das bayerische Bürgerkonto für Kommunen in Bayern." },
          { logo: "adm/apps/logo_servicekonto_nrw.png",  icon: "shield_person",   name: "servicekonto.NRW",     description: "Identitätsprüfung über das zentrale Servicekonto für Nordrhein-Westfalen." },
          { logo: "adm/apps/logo_openrathaus.png",       icon: "shield_person",   name: "OpenRathaus",          description: "Identitätsprüfung über die OpenRathaus-Plattform für kommunale Dienste." },
          { logo: "adm/apps/logo_letter.png",            icon: "mail_lock",       name: "Briefverifizierung",   description: "Verifizierung per Postbrief an die gemeldete Adresse – geeignet für Beteiligungen mit Wohnsitzpflicht." },
          { logo: "adm/apps/logo_sms.png",               icon: "sms",             name: "SMS-Verifizierung",    description: "Bestätigung der Telefonnummer per Einmal-Code (OTP) als niedrigschwellige Verifikationsstufe." }
        ]
      },
      {
        category: "Künstliche Intelligenz",
        icon: "smart_toy",
        apps: [
          { codename: "voice_assistant",
            icon: "record_voice_over",                                             name: "Voice Assistant",        description: "Beiträge und Mängelanzeigen per Spracheingabe einreichen. Senkt die Einstiegshürde und macht digitale Beteiligung für alle zugänglich." },
          { logo: "adm/apps/logo_ai_project_creation.png",  icon: "auto_awesome",    name: "AI-Projektassistent",    description: "Unterstützt Verwaltungsmitarbeitende beim Anlegen neuer Beteiligungsprojekte – von Beschreibung bis Zeitplan." },
          { logo: "adm/apps/logo_ai_user_help.png",         icon: "support_agent",   name: "AI-Nutzerhelfer",        description: "Beantwortet Bürgerfragen zur Plattform und zu laufenden Projekten direkt im Chatfenster." },
          { logo: "adm/apps/logo_ai_proposal_creation.png", icon: "lightbulb",       name: "AI-Vorschlagsgenerator", description: "Hilft Bürgerinnen und Bürgern, ihre Ideen als strukturierte Vorschläge zu formulieren." },
          { logo: "adm/apps/logo_ai_evaluation_phases.png", icon: "analytics",       name: "AI-Auswertung",          description: "Fasst eingegangene Beiträge thematisch zusammen und erstellt automatische Auswertungsberichte." },
          { logo: "adm/apps/logo_ai_project_chat.png",      icon: "forum",           name: "AI-Diskussionsbegleiter", description: "Moderiert Kommentarbereiche, erkennt thematische Cluster und gibt Zusammenfassungen der Debatte." }
        ]
      },
      {
        category: "Web-Tracking",
        icon: "bar_chart",
        apps: [
          { logo: "adm/apps/logo_matomo.png",            icon: "bar_chart",       name: "Matomo (Cookie)",       description: "Datenschutzkonforme Nutzungsanalyse mit Session-Cookies. Vollständige Datenkontrolle auf eigenem Server." },
          { logo: "adm/apps/logo_matomo.png",            icon: "bar_chart",       name: "Matomo (Cookieless)",   description: "DSGVO-freundliches Tracking ohne Cookies – keine Einwilligung erforderlich, volle Datensouveränität." }
        ]
      },
      {
        category: "3D-Karten",
        icon: "map",
        apps: [
          { logo: "adm/apps/logo_masterportal.png",      icon: "layers",          name: "Masterportal",          description: "Integration des Open-Source-Geoportals Masterportal für interaktive Geodatenvisualisierungen im Beteiligungsprozess." },
          { logo: "adm/apps/logo_vcsystems.png",         icon: "view_in_ar",      name: "Virtual City Systems",  description: "3D-Stadtmodelle von Virtual City Systems als räumlicher Kontext für Planungs- und Beteiligungsverfahren." }
        ]
      },
      {
        category: "Suche",
        icon: "search",
        apps: [
          { logo: "adm/apps/logo_elasticsearch.png",     icon: "manage_search",   name: "Elasticsearch",         description: "Leistungsstarke Volltextsuche über alle Beteiligungsinhalte – schnell, relevant und skalierbar." }
        ]
      },
      {
        category: "Übersetzung",
        icon: "translate",
        apps: [
          { logo: "adm/apps/logo_microsoft_translate.png", icon: "translate",     name: "Microsoft Translator",  description: "Automatische Übersetzung von Plattforminhalten und Bürgerbeiträgen über die Azure Cognitive Services." },
          { logo: "adm/apps/logo_google_translate.png",    icon: "translate",     name: "Google Translator",     description: "Automatische Übersetzung über die Google Cloud Translation API für mehrsprachige Beteiligung." }
        ]
      },
      {
        category: "Nutzerverwaltung & Konferenz",
        icon: "groups",
        apps: [
          { logo: "adm/apps/logo_brevo.png",             icon: "mail",            name: "Brevo",         description: "E-Mail-Marketing und Nutzerverwaltung über Brevo – Newsletter, Segmentierung und automatisierte Kampagnen." },
          { logo: "adm/apps/logo_jitsi.png",             icon: "video_call",      name: "Jitsi",         description: "Open-Source-Videokonferenzen direkt auf der Plattform – ohne externe Anmeldung oder proprietäre Software." },
          { logo: "adm/apps/logo_bbb.png",               icon: "video_chat",      name: "BigBlueButton", description: "Webkonferenz-Lösung für digitale Bürgerversammlungen mit Präsentationsmodus, Umfragen und Breakout-Räumen." }
        ]
      },
      {
        category: "Beteiligungsphasen",
        icon: "how_to_vote",
        apps: [
          { logo: "adm/apps/logo_livestream.png",        icon: "live_tv",         name: "YouTube Livestream", description: "Einbindung von YouTube-Livestreams in Beteiligungsprojekte für öffentliche Sitzungen und Informationsveranstaltungen." },
          { logo: "adm/apps/logo_newsfeed.png",          icon: "rss_feed",        name: "RSS-Newsfeed",       description: "Automatisches Einlesen externer Nachrichtenquellen per RSS als Informationsgrundlage für Beteiligungsprozesse." }
        ]
      }
    ].freeze

    def show
      authorize [:adm, :apps]
      @breadcrumbs = [{ name: t("adm.apps.show.title"), icon: "dashboard" }]

      @categories = APP_CATALOG.map do |cat|
        apps = cat[:apps].map do |app_def|
          app_def.merge(status: app_status(app_def[:codename]))
        end

        cat.merge(apps: apps)
      end
    end

    private

      def app_status(codename)
        case codename
        when "voice_assistant"
          Ai::Settings.ai_available? ? "active" : "inactive"
        else
          "inactive"
        end
      end
  end
end
