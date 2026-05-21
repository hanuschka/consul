class Adm::Dashboard::NoticeComponent < ApplicationComponent
  attr_reader :message

  def initialize(message:)
    @message = message
  end

  def render?
    message.present?
  end

  def storage_key
    "adm-notice-dismissed-#{Digest::SHA1.hexdigest(message.to_s)[0, 12]}"
  end
end
