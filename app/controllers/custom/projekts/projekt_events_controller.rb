module Projekts
  class ProjektEventsController < ApplicationController
    include CustomHelper
    include ProposalsHelper
    include ProjektControllerHelper

    skip_authorization_check
    has_orders %w[all incoming past], only: [:index]

    before_action do
      raise FeatureFlags::FeatureDisabled, :projekt_events_page unless Setting['extended_feature.general.enable_projekt_events_page']
    end

    def index
      @valid_orders = %w[all incoming past]
      @current_order = @valid_orders.include?(params[:order]) ? params[:order] : @valid_orders.first
      @projekt_events = ProjektEvent.all.page(params[:page]).send("sort_by_#{@current_order}")
    end
  end
end
