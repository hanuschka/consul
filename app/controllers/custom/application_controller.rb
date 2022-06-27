require_dependency Rails.root.join("app", "controllers", "application_controller").to_s


class ApplicationController < ActionController::Base

  before_action :set_top_level_projekts_for_menu, :set_default_social_media_images, :set_partner_emails

  before_action :ensure_user_signed_in
  before_action :authenticate_http_basic, if: :http_basic_auth_site?

  private

  def ensure_user_signed_in
    return if user_signed_in?
    return if allowed_public_actions?

    redirect_to new_user_session_path
  end

  def allowed_public_actions?
    ( controller_name == 'sessions' && action_name == 'new' ) ||
      ( controller_name == 'passwords' && action_name.in?(%w[new edit create]) ) ||
      ( controller_name == 'confirmations' && action_name.in?(%w[new show create update]) ) ||
      ( controller_name == 'registrations' && action_name.in?(%w[new success]) )
  end

  def http_basic_auth_site?
    Rails.application.secrets.http_basic_auth &&
      controller_name == 'registrations' && action_name == 'new'
  end

  def all_selected_tags
    if params[:tags]
      params[:tags].split(",").map { |tag_name| Tag.find_by(name: tag_name) }.compact || []
    else
      []
    end
  end

  def set_top_level_projekts_for_menu
    @top_level_projekts_for_menu =Projekt.top_level_navigation
  end

  def set_default_social_media_images
    SiteCustomization::Image.all_images
    social_media_icon_path = SiteCustomization::Image.all.find_by(name: 'social_media_icon').image.url.split('?')[0]
    @social_media_icon_path = social_media_icon_path.include?('missing') ? nil : social_media_icon_path
    social_media_icon_twitter_path = SiteCustomization::Image.all.find_by(name: 'social_media_icon_twitter').image.url.split('?')[0]
    @social_media_icon_twitter_path = social_media_icon_twitter_path.include?('missing') ? nil : social_media_icon_twitter_path
  end

  def set_deficiency_report_votes(deficiency_reports)
    @deficiency_report_votes = current_user ? current_user.deficiency_report_votes(deficiency_reports) : {}
  end

  def set_projekts_for_selector
    @projekts = Projekt.top_level
  end

  def set_partner_emails
    filename = File.join(Rails.root, 'config', 'secret_emails.yml')
    @partner_emails = File.exist?(filename) ? File.readlines(filename).map(&:chomp) : []
  end
end
