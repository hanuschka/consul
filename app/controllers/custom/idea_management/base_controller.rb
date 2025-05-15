class IdeaManagement::BaseController < ApplicationController
  layout "admin"

  # include IdeasHelper
  # helper IdeasHelper

  before_action :set_namespace
  before_action :authenticate_user!
  before_action :verify_idea_manager, unless: :perform_authorization?
  skip_authorization_check unless: :perform_authorization?

  private

    def verify_idea_manager
      raise CanCan::AccessDenied unless current_user&.idea_manager? ||
        current_user&.administrator?
    end

    def set_namespace
      @namespace = :idea_management
    end

    def perform_authorization?
      # return false unless current_user&.idea_officer?

      controllers = %w[ideas memos]
      controller_name.in? controllers
    end
end
