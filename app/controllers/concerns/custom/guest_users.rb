module GuestUsers
  extend ActiveSupport::Concern

  included do
    before_action :current_user
    before_action :persist_guest_user_on_write
  end

  def current_user
    super || guest_user
  end

  def user_signed_in?
    current_user && !current_user.guest?
  end

  def authenticate_user_or_guest!
    authenticate_user! unless current_user.present?
  end

  private

    # A guest is identified purely by its session key. The User row is built
    # in memory here and only persisted on the first write (see
    # persist_guest_user_on_write), so idempotent GETs — including a bot
    # flood — never touch the database.
    def guest_user
      return @guest_user if @guest_user
      return unless session[:guest_user_id]

      @guest_user =
        User.find_by(email: "#{session[:guest_user_id]}@example.com", guest: true) ||
        initialize_guest_user(session[:guest_user_id])
    end

    # Materialises the in-memory guest on write requests, before the action
    # body saves the authored record. Only reached via CSRF-protected
    # POST/PATCH/DELETE, so the bot flood (idempotent GETs) cannot create rows.
    def persist_guest_user_on_write
      return if request.get? || request.head?
      return unless @guest_user&.new_record?

      @guest_user.save!
    rescue ActiveRecord::RecordNotUnique
      # A concurrent write for the same session key already inserted the row;
      # adopt the persisted record so this request's action can reference it.
      @guest_user = User.find_by(email: "#{session[:guest_user_id]}@example.com", guest: true)
    rescue StandardError => e
      Sentry.capture_exception(e)
    end
end
