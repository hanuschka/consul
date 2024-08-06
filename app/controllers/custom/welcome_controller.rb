require_dependency Rails.root.join("app", "controllers", "welcome_controller").to_s

class WelcomeController < ApplicationController
  include Takeable
  include ProjektControllerHelper
  include GuestUsers

  def welcome
    redirect_to root_path
  end

  def index
    @header = Widget::Card.header.first
    @content_cards = SiteCustomization::ContentCard.active.to_a

    if Setting.new_design_enabled?
      render :index_new
    else
      render :index
    end
  end

  def latest_activity; end
end
