class Users::SmsSessionsController < ApplicationController
  skip_authorization_check
  skip_before_action :set_return_url

  before_action :ensure_sms_login_enabled
  before_action :redirect_signed_in_user
  before_action :require_phone_in_session, only: [:edit, :update, :resend]

  invisible_captcha only: [:create], honeypot: :subtitle, timestamp_enabled: false

  def new
    session.delete(:sms_sign_in_intended_path)

    if params[:intended_path].present?
      store_location_for(:user, CGI.unescape(params[:intended_path]))
      session[:sms_sign_in_intended_path] = session[stored_location_key_for(:user)] if request.format.js?
    end
  end

  def create
    phone = Sms::PhoneNumber.normalize(params[:phone])
    @phone_input = params[:phone]

    if phone.nil?
      @phone_invalid = true
      flash.now[:alert] = t("sms_sign_in.errors.invalid_phone")
      return render_step(:new, :unprocessable_entity)
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
      render_step(:edit, :unprocessable_entity)
    else
      @code_invalid = true
      flash.now[:alert] = t("sms_sign_in.errors.expired_code")
      render_step(:edit, :unprocessable_entity)
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
        respond_to do |format|
          format.html { redirect_to sms_sign_in_code_path, notice: t("sms_sign_in.code_sent") }
          format.js do
            flash.now[:notice] = t("sms_sign_in.code_sent")
            render :edit
          end
        end
      when :rate_limited
        flash.now[:alert] = t("sms_sign_in.errors.rate_limited")
        render_step(failure_template, :too_many_requests)
      else
        flash.now[:alert] = t("sms_sign_in.errors.delivery_failed")
        render_step(failure_template, :unprocessable_entity)
      end
    end

    def render_step(template, html_status)
      respond_to do |format|
        format.html { render template, status: html_status }
        format.js { render template }
      end
    end

    def sign_in_phone_user
      user = User.find_or_create_by_phone!(session[:sms_sign_in_phone])
      session.delete(:sms_sign_in_phone)

      if user.hidden? || !user.active_for_authentication?
        session.delete(:sms_sign_in_intended_path)
        respond_to do |format|
          format.html { redirect_to new_sms_sign_in_path, alert: t("sms_sign_in.errors.account_blocked") }
          format.js do
            flash.now[:alert] = t("sms_sign_in.errors.account_blocked")
            render :new
          end
        end
      else
        sign_in(:user, user)
        respond_to do |format|
          format.html { redirect_to after_sign_in_path_for(user), notice: t("devise.sessions.signed_in") }
          format.js do
            @redirect_path = session.delete(:sms_sign_in_intended_path)
            session.delete(stored_location_key_for(:user))
            flash[:notice] = t("devise.sessions.signed_in")
            render :signed_in
          end
        end
      end
    end

    def ensure_sms_login_enabled
      raise ActionController::RoutingError, "Not Found" unless Setting["extended_feature.general.sms_login"].present?
    end

    def redirect_signed_in_user
      return unless user_signed_in?

      respond_to do |format|
        format.html { redirect_to root_path }
        format.js { render js: "window.location.reload();" }
      end
    end

    def require_phone_in_session
      return if session[:sms_sign_in_phone].present?

      respond_to do |format|
        format.html { redirect_to new_sms_sign_in_path }
        format.js { render :new }
      end
    end
end
