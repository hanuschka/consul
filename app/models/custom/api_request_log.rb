class ApiRequestLog < ApplicationRecord
  belongs_to :api_client, optional: true

  validates :http_method, presence: true
  validates :request_path, presence: true

  scope :not_pushed, -> { where(pushed_to_dt: false) }

  HTTP_METHOD_BADGE_VARIANTS = {
    "GET" => "info",
    "POST" => "success",
    "PATCH" => "warning",
    "PUT" => "warning",
    "DELETE" => "danger"
  }.freeze

  def http_method_badge_variant
    HTTP_METHOD_BADGE_VARIANTS.fetch(http_method, "info")
  end
end
