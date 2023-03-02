class Users::ResourceAuthorComponent < ApplicationComponent
  attr_reader :user

  def initialize(user:)
    @user = user
  end
end
