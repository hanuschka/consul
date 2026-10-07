# frozen_string_literal: true

class Api::IdeaOfficersController < Api::BaseController
  def index
    check_read_access!
    officers = paginate(Idea::Officer.includes(:user))

    serialized_officers = IdeaOfficerSerializer.serialize_collection(officers)

    render json: {
      data: { idea_officers: serialized_officers },
      pagination: pagination_meta(officers)
    }
  end

  private
end
