module Adm
  class AppsController < Adm::BaseController
    APP_CATALOG = [
      {
        category_key: "registration",
        icon: "person_add",
        apps: [
          { key: "facebook_login",   logo: "adm/apps/logo_facebook.png",  icon: "thumb_up" },
          { key: "google_login",     logo: "adm/apps/logo_google.png",    icon: "search" },
          { key: "x_login",          logo: "adm/apps/logo_x.png",         icon: "tag" },
          { key: "wordpress_login",  logo: "adm/apps/logo_wordpress.png", icon: "rss_feed" }
        ]
      },
      {
        category_key: "verification",
        icon: "verified_user",
        apps: [
          { key: "bundid",              logo: "adm/apps/logo_bundid.png",           icon: "shield_person" },
          { key: "bayernid",            logo: "adm/apps/logo_bayernid.png",         icon: "shield_person" },
          { key: "servicekonto_nrw",    logo: "adm/apps/logo_servicekonto_nrw.png", icon: "shield_person" },
          { key: "openrathaus",         logo: "adm/apps/logo_openrathaus.png",      icon: "shield_person" },
          { key: "letter_verification", logo: "adm/apps/logo_letter.png",           icon: "mail_lock" },
          { key: "sms_verification",    logo: "adm/apps/logo_sms.png",              icon: "sms" }
        ]
      },
      {
        category_key: "ai",
        icon: "smart_toy",
        apps: [
          { key: "voice_assistant",      codename: App::VOICE_ASSISTANT_CODENAME, icon: "record_voice_over" },
          { key: "ai_project_creation",  logo: "adm/apps/logo_ai_project_creation.png",  icon: "auto_awesome" },
          { key: "ai_user_help",         logo: "adm/apps/logo_ai_user_help.png",         icon: "support_agent" },
          { key: "ai_proposal_creation", logo: "adm/apps/logo_ai_proposal_creation.png", icon: "lightbulb" },
          { key: "ai_evaluation_phases", logo: "adm/apps/logo_ai_evaluation_phases.png", icon: "analytics" },
          { key: "ai_project_chat",      logo: "adm/apps/logo_ai_project_chat.png",      icon: "forum" }
        ]
      },
      {
        category_key: "web_tracking",
        icon: "bar_chart",
        apps: [
          { key: "matomo_cookie",     logo: "adm/apps/logo_matomo.png", icon: "bar_chart" },
          { key: "matomo_cookieless", logo: "adm/apps/logo_matomo.png", icon: "bar_chart" }
        ]
      },
      {
        category_key: "maps_3d",
        icon: "map",
        apps: [
          { key: "masterportal",         logo: "adm/apps/logo_masterportal.png", icon: "layers" },
          { key: "virtual_city_systems", logo: "adm/apps/logo_vcsystems.png",    icon: "view_in_ar" }
        ]
      },
      {
        category_key: "search",
        icon: "search",
        apps: [
          { key: "elasticsearch", logo: "adm/apps/logo_elasticsearch.png", icon: "manage_search" }
        ]
      },
      {
        category_key: "translation",
        icon: "translate",
        apps: [
          { key: "microsoft_translator", logo: "adm/apps/logo_microsoft_translate.png", icon: "translate" },
          { key: "google_translator",    logo: "adm/apps/logo_google_translate.png",    icon: "translate" }
        ]
      },
      {
        category_key: "user_management",
        icon: "groups",
        apps: [
          { key: "brevo",         logo: "adm/apps/logo_brevo.png", icon: "mail" },
          { key: "jitsi",         logo: "adm/apps/logo_jitsi.png", icon: "video_call" },
          { key: "bigbluebutton", logo: "adm/apps/logo_bbb.png",   icon: "video_chat" }
        ]
      },
      {
        category_key: "participation",
        icon: "how_to_vote",
        apps: [
          { key: "youtube_livestream", logo: "adm/apps/logo_livestream.png", icon: "live_tv" },
          { key: "rss_newsfeed",       logo: "adm/apps/logo_newsfeed.png",   icon: "rss_feed" }
        ]
      }
    ].freeze

    def show
      authorize [:adm, :apps]
      @breadcrumbs = [{ name: t("adm.apps.show.title"), icon: "dashboard" }]

      db_apps = App.all.index_by(&:codename)

      @categories = APP_CATALOG.map do |cat|
        apps = cat[:apps].map do |app_def|
          codename = app_def[:codename]
          record   = codename ? db_apps[codename] : nil
          status   = record ? record.status : "inactive"

          app_def.merge(
            name:        t("adm.apps.show.apps.#{app_def[:key]}.name"),
            description: t("adm.apps.show.apps.#{app_def[:key]}.description"),
            status:      status
          )
        end

        cat.merge(
          category: t("adm.apps.show.categories.#{cat[:category_key]}"),
          apps: apps
        )
      end
    end
  end
end
