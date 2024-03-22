module LinksHelper
  def render_destroy_element_link(builder, element)
    link_to_remove_association element.new_record? ? t("links.form.cancel_button") :
                                                     t("links.form.delete_button"),
                                                     builder, class: "delete remove-element"
  end

  def link_to_signin(options = {})
    link_to t("users.signin"), new_user_session_path, options
  end

  def link_to_signup(options = {})
    link_to t("users.signup"), new_user_registration_path, options
  end

  def link_to_verify_account
    link_to t("users.verify_account"), user_servicekonto_nrv_omniauth_authorize_path, method: :post
  end

  def link_to_verify_account_short
    link_to t("custom.users.verify_account_link_short"), user_servicekonto_nrv_omniauth_authorize_path, method: :post
  end

  def link_to_guest_signin
    link_to "Gast teilnehmen", new_guest_user_registration_path
  end
end
