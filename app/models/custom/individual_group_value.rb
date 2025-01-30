class IndividualGroupValue < ApplicationRecord
  belongs_to :individual_group
  has_many :user_individual_group_values, dependent: :destroy
  has_many :users, through: :user_individual_group_values

  validates :name, presence: true

  scope :hard, -> { joins(:individual_group).where(individual_groups: { kind: "hard" }) }
  scope :soft, -> { joins(:individual_group).where(individual_groups: { kind: "soft" }) }

  around_save :update_user_assignments

  def add_from_csv(file_path)
    CSV.foreach(file_path, headers: true) do |row|
      user = User.find_by(email: row["email"])
      next unless user
      next if users.include?(user)

      users << user
    end
  end

  private

    def update_user_assignments
      if email_pattern_changed? && email_pattern.start_with?("@")
        users_to_add = User.where("email LIKE ?", "%#{email_pattern}").where.not(id: users.ids)
        users << users_to_add
      end

      yield
    end
end
