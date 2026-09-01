require_dependency Rails.root.join("app", "controllers", "welcome_controller").to_s

class WelcomeController < ApplicationController
  include Takeable
  include ProjektControllerHelper
  include GuestUsers

  helper DeficiencyReportsHelper

  def welcome
    redirect_to root_path
  end

  def index
    @header_image = header_image_attachment("header_image", "header_large")
    @mobile_header_image = header_image_attachment("mobile_header_image", "header_mobile")
    @header_video = SiteCustomization::Video.find_by(name: "header_video")&.persisted_video
    @mobile_header_video = SiteCustomization::Video.find_by(name: "mobile_header_video")&.persisted_video
    @content_cards = SiteCustomization::ContentCard.homepage.active.to_a

    respond_to do |format|
      format.html do
        if Setting.new_design_enabled?
          render :index_new
        else
          render :index
        end
      end
    end
  end

  def latest_activity
    @content_card = SiteCustomization::ContentCard.homepage.find_by(kind: "latest_user_activity")
  end

  private

    def header_image_attachment(image_name, card_title)
      site_image = SiteCustomization::Image.by_name(image_name)

      return site_image.image if site_image&.persisted_attachment?

      Widget::Card.header.find_by(title: card_title)&.image&.attachment
    end
end
