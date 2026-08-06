module Whatsapp::TokenDigest
  LENGTH = 6

  module_function

  def for(scope, record_id)
    OpenSSL::HMAC
      .hexdigest("SHA256", Rails.application.secret_key_base, "whatsapp-#{scope}-#{record_id}")
      .first(LENGTH)
  end

  def valid?(scope, record_id, digest)
    ActiveSupport::SecurityUtils.secure_compare(digest.to_s.downcase, self.for(scope, record_id))
  end
end
