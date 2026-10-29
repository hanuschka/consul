# Rails 7.0 derives cookie keys with SHA256. Keep reading cookies written with
# the SHA1-derived keys so existing sessions survive the upgrade. Remove once
# every session issued before the upgrade has expired.
Rails.application.config.after_initialize do
  Rails.application.config.action_dispatch.cookies_rotations.tap do |cookies|
    action_dispatch_config = Rails.application.config.action_dispatch
    cookie_cipher = action_dispatch_config.encrypted_cookie_cipher || "aes-256-gcm"
    sha1_key_generator = ActiveSupport::KeyGenerator.new(
      Rails.application.secret_key_base,
      iterations: 1000,
      hash_digest_class: OpenSSL::Digest::SHA1
    )
    encrypted_cookie_secret = sha1_key_generator.generate_key(
      action_dispatch_config.authenticated_encrypted_cookie_salt,
      ActiveSupport::MessageEncryptor.key_len(cookie_cipher)
    )
    signed_cookie_secret = sha1_key_generator.generate_key(action_dispatch_config.signed_cookie_salt)

    cookies.rotate :encrypted, encrypted_cookie_secret, cipher: cookie_cipher
    cookies.rotate :signed, signed_cookie_secret
  end
end
