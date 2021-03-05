require_dependency Rails.root.join("app", "models", "user").to_s

class User
  validates :plz, numericality: true, length: { is: 5 }, allow_blank: true
end
