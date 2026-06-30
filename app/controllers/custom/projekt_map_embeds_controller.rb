class ProjektMapEmbedsController < ApplicationController
  include HasEmbeddableShortcodes

  # Public endpoint: visibility is enforced inline (visible_for? / can?(:update))
  # rather than via CanCanCan, like other public controllers (e.g. PagesController).
  skip_authorization_check

  # Renders the same map markup the {{projekt_map}} shortcode produces on the
  # server, so the studio editor and any client-side insertion can hydrate a
  # map-embed placeholder with output identical to the published page.
  def show
    projekt = Projekt.find(params[:projekt_id])

    unless projekt.visible_for?(current_user) || can?(:update, projekt)
      return head :forbidden
    end

    render html: process_shortcodes("{{projekt_map}}", projekt: projekt).html_safe, layout: false
  end

  # No-projekt context (e.g. the homepage): renders the city-wide map with all
  # visible projekts as pins, identical to the published homepage output.
  def index
    render html: process_shortcodes("{{projekt_map}}").html_safe, layout: false
  end
end
