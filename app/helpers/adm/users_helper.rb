module Adm::UsersHelper
  def adm_user_status_badge(user)
    if user.hidden?
      ["hidden", "kern-badge--danger"]
    elsif user.confirmed?
      ["confirmed", "kern-badge--success"]
    else
      ["unconfirmed", "kern-badge--warning"]
    end
  end
end
