require_dependency Rails.root.join("app", "controllers", "users_controller").to_s

class UsersController < ApplicationController
  include FeatureFlags

  skip_authorization_check

  before_action :check_users_overview_enabled, only: :index

  def index
    @users = User.active.where(show_in_users_overview: true, guest: false).order(created_at: :desc).page(params[:page])
  end

  def show
    raise CanCan::AccessDenied if params[:filter] == "follows" && !valid_interests_access?(@user)

    if @user.erased? || @user.guest?
      head :not_found
    elsif @user == current_user
      redirect_to account_path
    elsif Setting.new_design_enabled?
      render :show_new
    else
      render :show
    end
  end

  private

    def check_users_overview_enabled
      raise FeatureFlags::FeatureDisabled, :users_overview unless Setting["extended_feature.general.users_overview_page"].present?
    end
end
