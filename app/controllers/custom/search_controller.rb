class SearchController < ApplicationController
  before_action :authenticate_user!, except: [:index]
  skip_authorization_check
  def index
    search_params = {}
    search_params[:q] = params[:q]
    search_params[:page] = params[:page]
    search_params[:section] = params[:section]
    search_params[:tag] = params[:tag]

    search_params[:locale] = I18n.locale.to_s
    @results = Searches::Generic.perform(search_params, params[:page]&.to_i)
  end
end