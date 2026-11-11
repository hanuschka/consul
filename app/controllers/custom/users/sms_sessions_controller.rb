class Users::SmsSessionsController < ApplicationController
  skip_authorization_check

  before_action :ensure_sms_login_enabled
  before_action :redirect_signed_in_user
  before_action :require_phone_in_session, only: [:edit, :update, :resend]

  def new
    store_location_for(:user, CGI.unescape(params[:intended_path])) if params[:intended_path].present?
  end

  def create
    phone = Sms::PhoneNumber.normalize(params[:phone])
    @phone_input = params[:phone]

    if phone.nil?
      @phone_invalid = true
      flash.now[:alert] = t("sms_sign_in.errors.invalid_phone")
      return render :new, status: :unprocessable_entity
    end

    send_code(phone, failure_template: :new)
  end

  def edit
  end

  def update
    case PhoneSignInCode.verify(phone: session[:sms_sign_in_phone], code: params[:code])
    when :verified
      sign_in_phone_user
    when :invalid
      @code_invalid = true
      flash.now[:alert] = t("sms_sign_in.errors.invalid_code")
      render :edit, status: :unprocessable_entity
    else
      @code_invalid = true
      flash.now[:alert] = t("sms_sign_in.errors.expired_code")
      render :edit, status: :unprocessable_entity
    end
  end

  def resend
    send_code(session[:sms_sign_in_phone], failure_template: :edit)
  end

  private

    def send_code(phone, failure_template:)
      case PhoneSignInCode.issue(phone: phone, ip: request.remote_ip)
      when :sent
        session[:sms_sign_in_phone] = phone
        redirect_to sms_sign_in_code_path, notice: t("sms_sign_in.code_sent")
      when :rate_limited
        flash.now[:alert] = t("sms_sign_in.errors.rate_limited")
        render failure_template, status: :too_many_requests
      else
        flash.now[:alert] = t("sms_sign_in.errors.delivery_failed")
        render failure_template, status: :unprocessable_entity
      end
    end

    def sign_in_phone_user
      user = User.find_or_create_by_phone!(session[:sms_sign_in_phone])
      session.delete(:sms_sign_in_phone)

      if user.hidden? || !user.active_for_authentication?
        redirect_to new_sms_sign_in_path, alert: t("sms_sign_in.errors.account_blocked")
      else
        sign_in(:user, user)
        redirect_to after_sign_in_path_for(user), notice: t("devise.sessions.signed_in")
      end
    end

    def ensure_sms_login_enabled
      raise ActionController::RoutingError, "Not Found" unless Setting["extended_feature.general.sms_login"].present?
    end

    def redirect_signed_in_user
      redirect_to root_path if user_signed_in?
    end

    def require_phone_in_session
      redirect_to new_sms_sign_in_path if session[:sms_sign_in_phone].blank?
    end
end
