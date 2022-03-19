class SearchController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  skip_authorization_check
  load_and_authorize_resource

  def index
    search_params = {}
    search_params[:q] = params[:q]
    search_params[:page] = params[:page]
    search_params[:section] = params[:section]
    search_params[:tag] = params[:tag]
    search_params[:projekts] = params[:projekts].split(',') if params[:projekts]

    search_params[:locale] = I18n.locale.to_s
    @results = Searches::Generic.perform(search_params, params[:page]&.to_i)

    @top_level_active_projekts = Projekt.top_level.current
    @top_level_archived_projekts = Projekt.top_level.expired
  end
end
