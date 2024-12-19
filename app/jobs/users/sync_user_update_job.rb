class Users::SyncUserUpdateJob < ApplicationJob
  queue_as :default

  def perform(user)
    user_serialized = {
      id: user.id,
      roles: (user.roles.presence || [""])
    }

    DtApi.new(ApiClient.dt.service_api_token).update_user(user.id, user_serialized)
  end
end
