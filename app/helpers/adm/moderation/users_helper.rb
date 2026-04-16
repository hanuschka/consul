module Adm::Moderation::UsersHelper
  def moderation_user_status(user)
    Activity.where(actionable: user, action: [:hide, :block]).last&.action || "block"
  end
end
