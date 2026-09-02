class IndividualGroupValue < ApplicationRecord
  belongs_to :individual_group
  has_many :user_individual_group_values, dependent: :destroy
  has_many :users, through: :user_individual_group_values

  validates :name, presence: true

  scope :hard, -> { joins(:individual_group).where(individual_groups: { kind: "hard" }) }
  scope :soft, -> { joins(:individual_group).where(individual_groups: { kind: "soft" }) }

  around_save :update_user_assignments

  def add_from_csv(file_path)
    return unless File.exist?(file_path)

    CSV.foreach(file_path, headers: true, encoding: "bom|utf-8") do |row|
      apply_email(row["email"])
    end

    auto_join_emails.reject!(&:blank?)
    save!
  end

  def add_email(email)
    return false unless apply_email(email)

    auto_join_emails.reject!(&:blank?)
    save!
    true
  end

  def add_user(user)
    return false if user.blank?

    users << user unless users.include?(user)
    remove_auto_join_email(user.email)
    true
  end

  def stored_email?(email)
    email = normalize_email(email)
    return false if email.blank?

    auto_join_emails.include?(email) || users.exists?(["LOWER(users.email) = ?", email])
  end

  def remove_auto_join_email(email)
    email = normalize_email(email)
    return if email.blank?
    return unless auto_join_emails.include?(email)

    auto_join_emails.delete(email)
    save!
  end

  private

    def apply_email(email)
      email = normalize_email(email)
      return false if email.blank?

      user = User.find_by(email: email)

      if user.present?
        users << user unless users.include?(user)
        auto_join_emails.delete(email) if auto_join_emails.include?(email)
      else
        auto_join_emails << email unless auto_join_emails.include?(email)
      end

      true
    end

    def update_user_assignments
      if email_pattern_changed? && email_pattern.start_with?("@")
        users_to_add = User.where("email LIKE ?", "%#{email_pattern}").where.not(id: users.ids)
        users << users_to_add
      end

      yield
    end

    def normalize_email(email)
      return if email.blank?

      email.strip.downcase.gsub(/[[:space:]\u200B\uFEFF]/, '')
    end
end
