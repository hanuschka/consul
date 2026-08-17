require_dependency Rails.root.join("app", "controllers", "application_controller").to_s

class ApplicationController < ActionController::Base
  # Pages a closed member instance still has to answer to anybody: the legally required ones, plus
  # whatever it takes to get into an account. Sign-up is not among them — on a member instance the
  # member list is the only way in.
  MEMBER_INSTANCE_PUBLIC_PAGES = %w[impressum privacy additional_privacy conditions
                                    accessibility].freeze

  MEMBER_INSTANCE_PUBLIC_DEVISE_ACTIONS = {
    "sessions" => %w[new create destroy],
    "passwords" => %w[new create edit update],
    "confirmations" => %w[new create show],
    "unlocks" => %w[new create show],
    # Erasing one's own account has to stay reachable for somebody the gate no longer lets in.
    "registrations" => %w[delete_form delete destroy]
  }.freeze

  before_action :sanitize_pagination_params
  before_action :normalize_tags_param
  before_action :set_projekts_for_overview_page_navigation,
                :set_default_social_media_images, :set_partner_emails
  before_action :enforce_member_instance_access, if: -> { Brevo::Settings.member_instance? }
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

    # Overrides CanCan's default so a request arriving from an on-behalf-of account mail can read the
    # one hidden record that mail was about. Everything else about the visitor is unchanged: the
    # token adds a single rule and grants nothing when it is missing, stale or forged.
    def current_ability
      @current_ability ||= Ability.new(current_user, preview_gid: on_behalf_of_preview_gid)
    end

    # Memoized with defined? rather than ||= because almost every request has no token, and a nil
    # result should not mean verifying a signature again on the next call.
    def on_behalf_of_preview_gid
      return @on_behalf_of_preview_gid if defined?(@on_behalf_of_preview_gid)

      @on_behalf_of_preview_gid = ResourcePreviewToken.resource_gid(
        params[:preview_token], purpose: OnBehalfOfAccountMailer::PREVIEW_PURPOSE
      )
    end

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

      normalized_tags = ::Tags::ExistingNamesService.call(params[:tags]).presence&.join(",")
      params[:tags] = normalized_tags

      if normalized_tags.blank?
        request.query_parameters.delete("tags")
      else
        request.query_parameters["tags"] = normalized_tags
      end
    end

    # AP1 of CON-2846: the restriction covers the whole site, not individual projekts, so it sits
    # here. /adm and /admin are unaffected — their base controllers do not inherit this one.
    #
    # A signed-in non-member is answered with a page, not a redirect: Devise's
    # require_no_authentication bounces an authenticated visitor from sessions#new back to
    # after_sign_in_path_for, which is gated again — login, root, login, root, forever.
    #
    # The 403 page carries no header, navigation or footer, which is the point: every one of them
    # links into content this visitor cannot open, and the page has to explain itself instead.
    def enforce_member_instance_access
      return if member_instance_public_request?
      return if current_user&.member_instance_access?

      if current_user.present?
        render "custom/pages/member_instance_forbidden", layout: false, status: :forbidden,
               formats: [:html]
      else
        redirect_to new_user_session_path, alert: t("custom.member_instance.sign_in_required")
      end
    end

    def member_instance_public_request?
      if devise_controller?
        return MEMBER_INSTANCE_PUBLIC_DEVISE_ACTIONS.fetch(controller_name, []).include?(action_name)
      end

      controller_name == "pages" && action_name == "show" &&
        params[:id].to_s.in?(MEMBER_INSTANCE_PUBLIC_PAGES)
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
      @current_ability = Ability.new(guest_user, preview_gid: on_behalf_of_preview_gid)
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
