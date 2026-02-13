module AdminHelper
  def namespaced_root_path
    "/#{namespace}"
  end

  def admin_namespace_for_current_user
    if current_user.present? && current_user.administrator?
      :admin
    elsif current_user.present? && current_user.projekt_manager?
      :projekt_management
    end
  end

  def namespaced_header_title
    if namespace == "moderation/budgets"
      t("moderation.header.title")
    elsif namespace == "management"
      t("management.dashboard.index.title")
    else
      t("#{namespace}.header.title")
    end
  end

  def official_level_options
    options = [["", 0]]
    (1..5).each do |i|
      options << [[t("admin.officials.level_#{i}"), setting["official_level_#{i}_name"]].compact.join(": "), i]
    end
    options
  end

  def admin_submit_action(resource)
    resource.persisted? ? "edit" : "new"
  end

  def user_roles(user)
    roles = []
    roles << :admin if user.administrator?
    roles << :moderator if user.moderator?
    roles << :valuator if user.valuator?
    roles << :manager if user.manager?
    roles << :poll_officer if user.poll_officer?
    roles << :official if user.official?
    roles << :organization if user.organization?
    roles
  end

  def display_user_roles(user)
    user_roles(user).join(", ")
  end

  def namespace
    controller.class.name.split("::").first.underscore
  end

  def namespace_projekt_phase_path(action: "update", url_params: {})
    url_for(controller: params[:controller], action: action, params: url_params, only_path: true)
  end

  def status_label_class(status)
    case status
    when "registration_in_progress"
      "secondary"
    when "registered"
      "success"
    else
      "primary"
    end
  end

  def access_level_label_class(level)
    case level
    when "public_data"
      "primary"
    when "admin"
      "alert"
    else
      "secondary"
    end
  end
end
