require_dependency Rails.root.join("app", "models", "image").to_s

class Image < ApplicationRecord
  def self.save_image_from_url(url)
    whitelisted_urls = [
      "http://graph.facebook.com/",
      "https://graph.facebook.com/"
    ]
    return unless whitelisted_urls.any? { |whitelisted_url| url.start_with?(whitelisted_url) }

    require "open-uri"

    tmp_folder = Rails.root.join("tmp")
    filename = "#{SecureRandom.hex(16)}.jpg"
    destination_path = File.join(tmp_folder, filename)

    open(destination_path, "wb") do |file|
      URI.open(url, "rb") do |img|
        file.write(img.read)
      end
    end

    destination_path
  end
end
