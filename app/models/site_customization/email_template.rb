class SiteCustomization::EmailTemplate < ApplicationRecord
  self.table_name = "site_customization_email_templates"

  EMAIL_TEMPLATES = {
    "Mailer#budget_investment_created" => {
      variables: %w[username investment_title projekt_title investment_url]
    },
    "Mailer#budget_investment_feasible" => {
      variables: %w[username investment_title projekt_title]
    },
    "Mailer#budget_investment_unfeasible" => {
      variables: %w[username investment_title projekt_title unfeasibility_explanation]
    },
    "Mailer#budget_investment_selected" => {
      variables: %w[username investment_title investment_url]
    },
    "Mailer#budget_investment_unselected" => {
      variables: %w[username investment_title investment_url projekt_title]
    },
    "Mailer#budget_investment_preselected" => {
      variables: %w[username investment_title investment_url projekt_title]
    },
    "Mailer#budget_investment_not_preselected" => {
      variables: %w[username investment_title investment_url projekt_title]
    },
    "Mailer#proposal_created" => {
      variables: %w[username proposal_title proposal_url]
    },
    "NotificationServiceMailer#new_proposal" => {
      variables: %w[username proposal_title proposal_url]
    },
    "NotificationServiceMailer#new_poll" => {
      variables: %w[username poll_title poll_url]
    },
    "NotificationServiceMailer#new_comment" => {
      variables: %w[username comment_body comment_url]
    },
    "NotificationServiceMailer#projekt_questions" => {
      variables: %w[username phase_url]
    },
    "NotificationServiceMailer#projekt_arguments" => {
      variables: %w[username phase_url]
    },
    "NotificationServiceMailer#new_projekt_notification" => {
      variables: %w[username phase_url]
    },
    "NotificationServiceMailer#new_projekt_event" => {
      variables: %w[username phase_url]
    },
    "NotificationServiceMailer#new_projekt_milestone" => {
      variables: %w[username phase_url]
    },
    "NotificationServiceMailer#new_projekt_livestream" => {
      variables: %w[username phase_url]
    },
    "NotificationServiceMailer#new_budget_investment" => {
      variables: %w[username investment_title investment_url projekt_title projekt_url]
    }
  }.freeze

  audited only: %i[subject body]

  belongs_to :projekt_phase, optional: true

  validates :mailer_class, presence: true
  validates :mailer_action, presence: true
  validates :locale, presence: true
  validates :mailer_action, uniqueness: { scope: [:projekt_phase_id, :mailer_class, :locale] }
  validate :template_key_must_be_registered

  def template_key
    "#{mailer_class}##{mailer_action}"
  end

  def registered_variables
    EMAIL_TEMPLATES.dig(template_key, :variables) || []
  end

  def render_subject(variables = {})
    return nil if subject.blank?

    Liquid::Template.parse(subject).render(variables.stringify_keys)
  rescue Liquid::Error
    nil
  end

  def render_body(variables = {})
    return nil if body.blank?

    Liquid::Template.parse(body).render(variables.stringify_keys)
  rescue Liquid::Error
    nil
  end

  def customized?
    subject.present? || body.present?
  end

  def self.find_template(projekt_phase, mailer_class, mailer_action, locale = I18n.locale)
    find_by(
      projekt_phase: projekt_phase,
      mailer_class: mailer_class,
      mailer_action: mailer_action,
      locale: locale
    )
  end

  private

    def template_key_must_be_registered
      unless EMAIL_TEMPLATES.key?(template_key)
        errors.add(:mailer_action, :not_registered)
      end
    end
end
