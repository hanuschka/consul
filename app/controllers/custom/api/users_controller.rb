class Api::UsersController < Api::BaseController
  include MapLocationAttributes
  include ImageAttributes

  before_action :find_projekt, only: [
    :update, :update_page, :import, :update_title_image
  ]
  before_action :process_tags, only: [:update]

  def mark_as_on_dt
    user = User.find(params[:id])

    if user.update(on_dt: true)
      render json: { status: "updated" }
    else
      render json: { status: "error updating user" }
    end
  end
end
