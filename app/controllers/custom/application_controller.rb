require_dependency Rails.root.join("app", "controllers", "application_controller").to_s

class ApplicationController < ActionController::Base
  include IframeEmbeddedBehavior
  include EmbeddedAuth
  prepend_before_action :authentificate_frame_session_user!

  before_action :set_projekts_for_overview_page_navigation,
                :set_default_social_media_images, :set_partner_emails
  after_action :set_back_path
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

    def all_selected_tags
      if params[:tags]
        params[:tags].split(",").map { |tag_name| Tag.find_by(name: tag_name) }.compact || []
      else
        []
      end
    end

    def set_projekts_for_overview_page_navigation
      return if embedded?

      @projekts_for_overview_page_navigation =
        Projekt
          .activated
          .sort_by_order_number
          .includes({page: [:translations]}, :projekt_settings, { children_projekts_show_in_navigation: :projekt_settings })
          .joins(:projekt_settings)
          .includes(:projekt_settings)
          .where(projekt_settings: { key: "projekt_feature.general.show_in_overview_page_navigation", value: "active" })
          .lazy
          .select { |p| p.visible_for?(current_user) }

      @projekts_for_navigation =
        Projekt
          .top_level
          .activated
          .includes(
            :projekt_settings, :hard_individual_group_values,
            page: [:translations]
          )
          .order(created_at: :asc)
          .show_in_navigation
          .sort_by_order_number
          .select { |p| p.visible_for?(current_user) }

      @draft_projekts_for_navigation =
        Projekt
          .regular
          .not_activated
          .includes(
            page: [:translations]
          )
          .order(created_at: :asc)
          .select { |p| p.visible_for?(current_user) }
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

    def set_back_path
      if params[:projekt_phase_id].present?
        back_path = helpers.url_to_footer_tab(extras: { anchor: "filter-subnav" })
      else
        back_path = request.fullpath
      end

      session[:back_path] = back_path
    end

    def auto_sign_in_guest_for(projekt_phase)
      return if current_user.present?
      return if projekt_phase.blank?
      return unless projekt_phase.user_status == "guest"
      return unless projekt_phase.current?

      guest_key = "guest_#{SecureRandom.uuid}"
      params[:user] = {}
      params[:user][:username] = guest_key
      params[:user][:terms_data_protection] = true
      params[:user][:terms_general] = true

      @guest_user = initialize_guest_user(guest_key)
      @guest_user.save!
      session[:guest_user_id] = guest_key

      @current_ability = Ability.new(current_user)
    rescue StandardError => e
      Sentry.capture_exception(e)
    end

    def initialize_guest_user(guest_key)
      User.new(
        username: params[:user][:username],
        terms_data_protection: params[:user][:terms_data_protection],
        terms_general: params[:user][:terms_general],
        email: "#{guest_key}@example.com",
        guest: true,
        confirmed_at: Time.now.utc,
        skip_password_validation: true
      )
    end

    def set_landing_page_topbar_ui_variables(landing_page)
      @ui_show_projekts_overview = landing_page.landing_show_projekts_overview
      @ui_hide_topbar_links = landing_page.landing_hide_all_top_nav_links

      if landing_page.landing_site_logo_for_transparent_background.attached?
        @ui_site_logo_transparent_background = url_for(landing_page.landing_site_logo_for_transparent_background)
      end

      if landing_page.landing_site_logo_for_white_background.attached?
        @ui_site_logo_white_background = url_for(landing_page.landing_site_logo_for_transparent_background)
      end

      if landing_page.landing_site_logo_follow_to_landing_page
        @ui_site_logo_path = landing_page.url
      end
    end
end
