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

  def machmit_jugend
    @active_projekts = Projekt.show_in_homepage
      .joins(:tags).where(tags: { name: "Jugendbeteiligung" })
      .index_order_underway
      .select { |p| p.visible_for?(current_user) }
      .sort_by(&:created_at).reverse
    @expired_projekts = Projekt.show_in_homepage
      .joins(:tags).where(tags: { name: "Jugendbeteiligung" })
      .index_order_expired
      .select { |p| p.visible_for?(current_user) }
      .sort_by(&:created_at).reverse
  end
end
