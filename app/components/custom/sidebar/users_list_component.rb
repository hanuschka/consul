class Sidebar::UsersListComponent < ApplicationComponent
  VISIBLE_USERS_LIMIT = 5

  # User#name reads through to the organization, so both associations are
  # needed to render one avatar row without a query per user.
  PRELOAD_ASSOCIATIONS = [
    :organization,
    { image: { attachment_attachment: :blob } }
  ].freeze

  def initialize(users:)
    @users = users
  end

  def visible_users
    @visible_users ||= @users.includes(PRELOAD_ASSOCIATIONS).last(VISIBLE_USERS_LIMIT)
  end
end
