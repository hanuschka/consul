require_dependency Rails.root.join("app", "controllers", "application_controller").to_s

class ApplicationController < ActionController::Base
  before_action :sanitize_pagination_params
  before_action :normalize_tags_param
  before_action :set_projekts_for_overview_page_navigation,
                :set_default_social_media_images, :set_partner_emails
  helper_method :set_comment_flags

  # unless Rails.env.production?
  #   around_action :n_plus_one_detection
  #
  #   def n_plus_one_detection
  #     Prosopite.scan
  #     yield
  #   ensure
  #     Prosopite.finish
  #   end
  # end

  private
    def sanitize_pagination_params
      %i[page per_page resource_browse_mode_page].each do |key|
        value = params[key]
        next if value.nil? || value.is_a?(String) || value.is_a?(Numeric)

        params[key] = nil
      end
    end

    # Tag names that match no tag are dropped here so nothing downstream can
    # echo them back into links, hidden fields or filter queries.
    def normalize_tags_param
      return if params[:tags].blank?

      normalized_tags = Tags::ExistingNamesService.call(params[:tags]).presence&.join(",")
      params[:tags] = normalized_tags

      if normalized_tags.blank?
        request.query_parameters.delete("tags")
      else
        request.query_parameters["tags"] = normalized_tags
      end
    end

    def show_launch_page?
      launch_date_setting = Setting["extended_option.general.launch_date"]
      return false if launch_date_setting.blank?

      return false if current_user&.administrator?

      return false if allowed_public_actions?

      begin
        launch_date = Date.strptime(launch_date_setting, "%d.%m.%Y")
        launch_date > Date.today
      rescue Date::Error
        false
      end
    end

    def allowed_public_actions?
      (controller_name == "sessions" && action_name == "new") ||
        (controller_name == "passwords" && action_name.in?(%w[new edit create])) ||
        (controller_name == "confirmations" && action_name.in?(%w[new show create update])) ||
        (controller_name == "registrations" && action_name.in?(%w[new create success check_username cancel edit update destroy delete_form delete finish_signup do_finish_signup]))
    end

    def show_launch_page
      @header_launch = Widget::Card.header.find_by(title: "header_large_launch")
      render "welcome/launch", layout: "launch_page"
    end

    def set_projekts_for_overview_page_navigation
      @projekts_for_overview_page_navigation = Projekt.for_overview_page_navigation(current_user)
                                                      .includes([page: :translations])
      @draft_projekts_for_navigation = Projekt.not_activated.visible_for(current_user).includes([page: :translations])
    end

    def set_default_social_media_images
      return if params[:controller] == "ckeditor/pictures"

      social_media_icon = SiteCustomization::Image.find_by(name: "social_media_icon")

      if social_media_icon&.image&.attached?
        @social_media_icon_path = polymorphic_path(social_media_icon.image)
      end

      twitter_icon = SiteCustomization::Image.find_by(name: "social_media_icon_twitter")

      if twitter_icon&.image&.attached?
        @social_media_icon_twitter_url = polymorphic_path(twitter_icon.image)
      end
    end

    def set_deficiency_report_votes(deficiency_reports)
      @deficiency_report_votes = current_user ? current_user.deficiency_report_votes(deficiency_reports) : {}
    end

    def set_projekts_for_selector
      @projekts = Projekt.top_level
    end

    def set_partner_emails
      filename = File.join(Rails.root, "config", "secret_emails.yml")
      @partner_emails = File.exist?(filename) ? File.readlines(filename).map { |l| l.chomp.downcase } : []
    end

    def javascript_request?
      request.format == "text/javascript"
    end

    def set_return_url
      return if javascript_request?
      return if request.xhr?

      if request.get? && !devise_controller? && is_navigational_format? && document_request?
        if request.fullpath.include?("/null")
          current_user_id = current_user.present? ? current_user.id : "not logged in"
          Sentry.capture_message("NULL exception. URL: #{request.base_url + request.fullpath} for user id: #{current_user_id}")
          redirect_to root_path

          return
        end

        store_location_for(:user, SessionUrlTruncator.truncate(request.fullpath))
      end

      if params[:projekt_phase_id].present?
        back_path = helpers.url_to_footer_tab(extras: { anchor: "filter-subnav" })
      else
        back_path = request.fullpath
      end

      session[:back_path] = SessionUrlTruncator.truncate(back_path)
    end

    BOT_USER_AGENT_REGEX = /
      bot|crawl|spider|slurp|fetch|preview|monitor|
      bing|yandex|baidu|duckduckbot|
      facebookexternalhit|twitterbot|linkedinbot|slackbot|whatsapp|telegram|discordbot|
      curl|wget|python|java\/|go-http-client|httpclient|ruby|okhttp|
      pingdom|uptimerobot|statuscake|newrelic|datadog
    /ix.freeze

    def bot_request?
      return true if request.head?

      ua = request.user_agent.to_s
      ua.blank? || ua.match?(BOT_USER_AGENT_REGEX)
    end

    # Establishes a guest identity for a guest-status phase on GET show pages.
    # Only assigns the session key (a cheap signed cookie) — the User row is
    # built in memory by GuestUsers#guest_user and persisted on the first write
    # (GuestUsers#persist_guest_user_on_write). No database write happens here,
    # so a bot flood of GETs cannot create rows.
    #
    # Previously this persisted a User on every GET; the UA-based bot_request?
    # guard is bypassed by spoofed browser UAs, so a flood inserted one row per
    # request and saturated the DB and Puma.
    def auto_sign_in_guest_for(projekt_phase)
      return if current_user.present? && !current_user.guest?
      return if projekt_phase.blank?
      return unless projekt_phase.user_status == "guest"
      return if bot_request?

      session[:guest_user_id] ||= "guest_#{SecureRandom.uuid}"
      @current_ability = Ability.new(guest_user)
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

    def initialize_guest_user(guest_key)
      User.new(
        username: guest_key,
        terms_data_protection: true,
        terms_general: true,
        email: "#{guest_key}@example.com",
        guest: true,
        guest_user_agent: request.user_agent.to_s.first(500),
        confirmed_at: Time.now.utc,
        skip_password_validation: true
      )
    end

end
