# frozen_string_literal: true

class Api::IdeaOfficersController < Api::BaseController
  def index
    check_read_access!
    officers = Idea::Officer
      .includes(:user)
      .page(params[:page])
      .per(params[:per_page] || DEFAULT_PER_PAGE)

    serialized_officers = IdeaOfficerSerializer.serialize_collection(officers)

    render json: {
      data: { idea_officers: serialized_officers },
      pagination: pagination_meta(officers)
    }
  end

  private

  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
