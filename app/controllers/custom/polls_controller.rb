require_dependency Rails.root.join("app", "controllers", "polls_controller").to_s

class PollsController < ApplicationController

  include CommentableActions

  before_action :load_categories, only: [:index]

  helper_method :resource_model, :resource_name

  def index
    @tag_cloud = tag_cloud
    if params[:tags].present?
      @polls = @polls.created_by_admin.not_budget.send(@current_filter).includes(:geozones).tagged_with(params[:tags].split(","), all: true).page(params[:page])
    else
      @polls = Kaminari.paginate_array(
        @polls.created_by_admin.not_budget.send(@current_filter).includes(:geozones).sort_for_list
      ).page(params[:page])
    end
  end

  private

    def section(resource_name)
      "polls"
    end

    def resource_model
      Poll
    end

    def take_only_by_tag_names
      if params[:tags].present?
        @resources = @resources.tagged_with(params[:tags].split(","), all: true, any: :true)
        @categories = @resources.tag_counts.category
      end
    end
end
