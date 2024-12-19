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
      render json: { status: "User updated" }
    else
      render json: { status: "User not found" }
    end
  end

  def id_by_email
    user = User.find_by(email: params[:email])

    if user.present?
      render json: { user_id: user.id }
    else
      render json: { status: "User not found" }
    end
  end
end
