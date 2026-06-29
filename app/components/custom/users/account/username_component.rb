class Users::Account::UsernameComponent < ApplicationComponent
  def initialize(user:, edit_mode: false)
    @user = user
    @edit_mode = edit_mode
  end
end
