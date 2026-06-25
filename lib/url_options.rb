module UrlOptions
  def self.default
    Rails.application.config.action_mailer.default_url_options
  end
end
