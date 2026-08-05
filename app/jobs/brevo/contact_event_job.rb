class Brevo::ContactEventJob < ApplicationJob
  queue_as :default

  # The webhook request itself only enqueues: Brevo retries on a slow or failing response, and
  # provisioning an account takes an API read plus a mail.
  def perform(payload)
    Brevo::ContactEventHandler.call(payload)
  end
end
