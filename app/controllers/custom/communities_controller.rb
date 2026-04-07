require_dependency Rails.root.join("app", "controllers", "communities_controller").to_s

class CommunitiesController < ApplicationController
  def show
    @communitable_resource = resolve_communitable
    raise ActionController::RoutingError, "Not Found" if @communitable_resource.blank?

    redirect_to root_path if Setting["feature.community"].blank?

    authorize! :show, @community

    @resource = @communitable_resource

    if Setting.new_design_enabled?
      render :show_new
    else
      render :show
    end
  end

  private

  def resolve_communitable
    if current_user&.administrator?
      Proposal.with_hidden.find_by(community_id: @community.id) ||
        Budget::Investment.with_hidden.find_by(community_id: @community.id)
    else
      @community.communitable
    end
  end
end
