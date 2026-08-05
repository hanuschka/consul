class Webhooks::BrevoController < ActionController::API
  # Brevo posts contact events here: POST /webhooks/brevo/member_events, authenticated with the
  # shared secret from config/secrets.yml. Brevo's webhook configuration cannot be relied on to
  # send a custom header on every plan, so the token is accepted either as a bearer token or as a
  # query parameter.
  #
  # The request only enqueues. Brevo retries anything that answers slowly or fails, and the work —
  # reading the contact back, opening an account, sending a mail — has no business happening inside
  # the request.
  before_action :ensure_webhook_configured!
  before_action :authenticate_webhook!

  def create
    unless Brevo::ContactEventHandler.relevant_event?(webhook_payload)
      return render json: { status: "ignored" }, status: :ok
    end

    Brevo::ContactEventJob.perform_later(webhook_payload)

    render json: { status: "accepted" }, status: :accepted
  end

  private

    def ensure_webhook_configured!
      return if Brevo::Settings.webhook_enabled?

      render json: { error: "Brevo member sync is not configured" }, status: :service_unavailable
    end

    def authenticate_webhook!
      return if ActiveSupport::SecurityUtils.secure_compare(provided_token, Brevo::Settings.webhook_token)

      render json: { error: "Invalid or missing webhook token" }, status: :unauthorized
    end

    def provided_token
      bearer = request.authorization.to_s[/\ABearer\s+(.+)\z/i, 1]

      (bearer || params[:token]).to_s
    end

    # Brevo sends a single event as a flat JSON object. Only the keys the handler knows are kept, so
    # an unexpectedly large payload cannot be pushed through into the job queue. Two keys are
    # dropped on purpose: `id`, which identifies the webhook rather than the contact, and `list_id`,
    # because list membership is read back from Brevo instead of trusted from the event.
    #
    # `email` is permitted twice because Brevo sends it both ways: one address as a string on
    # list_addition, an array of them on contact_deleted. Permitting only the scalar silently drops
    # the array, which leaves the handler an event it cannot attribute to anybody.
    #
    # `content` is the one part of a payload worth keeping beyond the address: on contact_updated it
    # names the lists the change added to or deleted from, which is what tells a member leaving the
    # association apart from somebody editing their phone number.
    def webhook_payload
      params.permit(:event, :email, :contact_id, :date, email: [], contact: [:id, :email],
                    content: [:email, list: { addition: [:id, :name], deletion: [:id, :name] }]).to_h
    end
end
