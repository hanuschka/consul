class Offer::Provider < ApplicationRecord
  has_many :provider_users, class_name: "Offer::ProviderUser", foreign_key: :offer_provider_id,
    dependent: :destroy, inverse_of: :provider
  has_many :users, through: :provider_users
  has_many :offers, foreign_key: :provider_id, inverse_of: :provider

  validates :name, presence: true
  validate :email_list_valid, unless: -> { @email_list.nil? }

  before_destroy :ensure_without_offers, prepend: true
  after_save :sync_email_list, unless: -> { @email_list.nil? }

  def self.for_user(user)
    return none unless user&.confirmed?

    where(id: Offer::ProviderUser.where(user_id: user.id).select(:offer_provider_id))
  end

  def emails
    (users.pluck(:email) + auto_join_emails).compact.map(&:downcase).uniq.sort
  end

  def email_list
    @email_list ? @email_list.join("\n") : emails.join("\n")
  end

  def email_list=(text)
    @email_list = text.to_s.split(/[\s,;]+/).filter_map { |email| normalize_email(email) }.uniq
  end

  def add_email(email)
    email = normalize_email(email)
    return false if email.blank?

    user = User.find_by("LOWER(email) = ?", email)

    if user.present?
      users << user unless users.include?(user)
      auto_join_emails.delete(email)
    else
      auto_join_emails << email unless auto_join_emails.include?(email)
    end

    save!
    true
  end

  def remove_email(email)
    email = normalize_email(email)
    return if email.blank?

    auto_join_emails.delete(email)
    provider_users.joins(:user).where("LOWER(users.email) = ?", email).destroy_all
    save!
  end

  def link_user(user)
    users << user unless users.include?(user)
    auto_join_emails.delete(normalize_email(user.email))
    save!
  end

  def safe_to_destroy?
    !offers.exists?
  end

  private

    def email_list_valid
      invalid = @email_list.reject { |email| email.match?(URI::MailTo::EMAIL_REGEXP) }
      return if invalid.empty?

      errors.add(:email_list, :invalid_emails, emails: invalid.join(", "))
    end

    def sync_email_list
      wanted = @email_list
      @email_list = nil

      (emails - wanted).each { |email| remove_email(email) }
      (wanted - emails).each { |email| add_email(email) }
    end

    def ensure_without_offers
      return if safe_to_destroy?

      errors.add(:base, I18n.t("activerecord.errors.messages.restrict_dependent_destroy.has_many",
                               record: Offer.model_name.human(count: 2)))
      throw :abort
    end

    def normalize_email(email)
      return if email.blank?

      email.strip.downcase.gsub(/[[:space:]​﻿]/, "")
    end
end
