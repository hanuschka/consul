module LinksHelper
  def render_destroy_element_link(builder, element)
    link_to_remove_association element.new_record? ? t("links.form.cancel_button") :
                                                     t("links.form.delete_button"),
                                                     builder, class: "delete remove-element"
  end

  def link_to_signin(options = {})
    query_params = options.slice(*query_params_keys)
    options = options.delete_if { |key, _| query_params_keys.include?(key) }
    link_to t("users.signin"), new_user_session_path(query_params), options
  end

  def link_to_signup(options = {})
    query_params = options.slice(*query_params_keys)
    options = options.delete_if { |key, _| query_params_keys.include?(key) }
    link_to t("users.signup"), new_user_registration_path(query_params), options
  end

  def link_to_verify_account
    link_to t("users.verify_account"), verification_path
  end

  def link_to_guest_signin(options = {})
    query_params = options.slice(*query_params_keys)
    options = options.delete_if { |key, _| query_params_keys.include?(key) }
    link_to t("custom.shared.participate_as_guest"), new_guest_user_registration_path(query_params), options
  end

  def link_to_enter_missing_user_data
    link_to t("custom.shared.enter_missing_user_data"), verification_path
  end

  def query_params_keys
    [:intended_path]
  end
end
