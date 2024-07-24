module EmbeddedAuth
  extend ActiveSupport::Concern

  included do
    before_action :set_iframe_content_security_policy
    helper_method :embedded?
    helper_method :user_authentificated_from_token?
  end

  private

    def authentificate_user_from_token!
      return if params[:temp_token].blank?
      return if current_user.present?

      @user_authentificated_from_token = true

      user = User.find_by(temporary_auth_token: params[:temp_token])

      if user.present? && user.temporary_auth_token_valid?
        sign_in user
      else
        raise "Invalid auth"
      end
    end

    def default_url_options
      @default_url_options ||= gen_default_url_options(super)
    end

    def gen_default_url_options(options)
      if params[:temp_token].present?
        options.merge({ temp_token: params[:temp_token] })
      end
      if params[:embedded].present?
        options.merge({ embedded: params[:embedded] })
      end

      options
    end

    def user_authentificated_from_token?
      @user_authentificated_from_token
    end
end
