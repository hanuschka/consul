# frozen_string_literal: true

class AuthorSerializer < BaseSerializer
  attr_reader :user

  def initialize(user, client: nil)
    @user = user
    @client = client
  end

  def serialize
    if admin_client?
      { id: user.id, public_name: user.public_name }
    else
      { public_name: user.public_name }
    end
  end
end
