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
    "Mailer#formular_answer_created" => {
      variables: %w[username projekt_title phase_title]
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
    },
    "NotificationServiceMailer#user_reverification_failed" => {
      variables: %w[last_name base_url]
    },
    "NotificationServiceMailer#user_reverification_succeeded" => {
      variables: %w[last_name]
    },
    "Mailer#comment" => {
      variables: %w[username commenter_name commentable_title commentable_url comment_body]
    },
    "Mailer#reply" => {
      variables: %w[username reply_body comment_url]
    },
    "Mailer#direct_message_for_receiver" => {
      variables: %w[username sender_name message_title message_body sender_url]
    },
    "Mailer#resource_hidden" => {
      variables: %w[username resource_text]
    },
    "Mailer#already_confirmed" => {
      variables: %w[username new_password_url]
    },
    "Mailer#manual_verification_confirmation" => {
      variables: %w[username]
    },
    "Mailer#newsletter_subscription_for_existing_user" => {
      variables: %w[username account_url]
    },
    "Mailer#user_invite" => {
      variables: %w[org_name registration_url]
    },
    "Mailer#pending_role_invite" => {
      variables: %w[org_name role_name registration_url]
    },
    "Mailer#csv_download_ready" => {
      variables: %w[username download_url]
    },
    "Mailer#file_ready" => {
      variables: %w[username file_name]
    },
    "Mailer#individual_group_value_users_added" => {
      variables: %w[username group_name group_value_name]
    },
    "Mailer#existing_stamp_notify_existing_user" => {
      variables: %w[username]
    },
    "Mailer#existing_stamp_notify_new_user" => {
      variables: %w[]
    },
    "Mailer#user_verification_failed" => {
      variables: %w[username verification_url]
    },
    "DeficiencyReportMailer#notify_author_about_status_change" => {
      variables: %w[username deficiency_report_title deficiency_report_url status_name status_notice_text]
    },
    "DeficiencyReportMailer#notify_officer" => {
      variables: %w[deficiency_report_id deficiency_report_title deficiency_report_url]
    },
    "DeficiencyReportMailer#notify_default_officer_group_email" => {
      variables: %w[deficiency_report_id deficiency_report_title deficiency_report_url]
    },
    "DeficiencyReportMailer#notify_author_about_submission" => {
      variables: %w[username deficiency_report_title deficiency_report_url account_url]
    },
    "DeficiencyReportMailer#send_feedback_form_link" => {
      variables: %w[username deficiency_report_title deficiency_report_url status_name feedback_form_url]
    },
    "NotificationServiceMailer#new_deficiency_report" => {
      variables: %w[username deficiency_report_id deficiency_report_title deficiency_report_url]
    },
    "NotificationServiceMailer#new_comments_for_deficiency_report" => {
      variables: %w[deficiency_report_title deficiency_report_url comment_count]
    },
    "NotificationServiceMailer#overdue_deficiency_reports" => {
      variables: %w[officer_name overdue_count]
    },
    "NotificationServiceMailer#overdue_deficiency_reports_overview" => {
      variables: %w[officer_name overdue_count fresh_count]
    },
    "NotificationServiceMailer#not_assigned_deficiency_reports" => {
      variables: %w[admin_name not_assigned_count]
    }
  }.freeze

  GLOBAL_EMAIL_TEMPLATES = [
    ["NotificationServiceMailer", "user_reverification_failed"],
    ["NotificationServiceMailer", "user_reverification_succeeded"],
    ["Mailer", "comment"],
    ["Mailer", "reply"],
    ["Mailer", "direct_message_for_receiver"],
    ["Mailer", "resource_hidden"],
    ["Mailer", "already_confirmed"],
    ["Mailer", "manual_verification_confirmation"],
    ["Mailer", "newsletter_subscription_for_existing_user"],
    ["Mailer", "user_invite"],
    ["Mailer", "pending_role_invite"],
    ["Mailer", "csv_download_ready"],
    ["Mailer", "file_ready"],
    ["Mailer", "individual_group_value_users_added"],
    ["Mailer", "existing_stamp_notify_existing_user"],
    ["Mailer", "existing_stamp_notify_new_user"],
    ["Mailer", "user_verification_failed"]
  ].freeze

  # Deficiency-report emails are not tied to a projekt phase (so they are stored
  # with projekt_phase: nil), but they are edited inside the /adm/deficiency_reports
  # section rather than on the generic global email-templates page.
  #
  # Grouped by recipient for display: emails to external users (the citizen who
  # filed the report) vs. emails to staff (admins, officers, managers). Within
  # each group the entries follow the report lifecycle
  # (submission -> assignment -> processing -> closing).
  DEFICIENCY_REPORT_EMAIL_TEMPLATE_GROUPS = {
    external: [
      ["DeficiencyReportMailer", "notify_author_about_submission"],
      ["DeficiencyReportMailer", "notify_author_about_status_change"],
      ["DeficiencyReportMailer", "send_feedback_form_link"]
    ],
    internal: [
      ["NotificationServiceMailer", "new_deficiency_report"],
      ["DeficiencyReportMailer", "notify_officer"],
      ["DeficiencyReportMailer", "notify_default_officer_group_email"],
      ["NotificationServiceMailer", "not_assigned_deficiency_reports"],
      ["NotificationServiceMailer", "new_comments_for_deficiency_report"],
      ["NotificationServiceMailer", "overdue_deficiency_reports"],
      ["NotificationServiceMailer", "overdue_deficiency_reports_overview"]
    ]
  }.freeze

  DEFICIENCY_REPORT_EMAIL_TEMPLATES =
    DEFICIENCY_REPORT_EMAIL_TEMPLATE_GROUPS.values.flatten(1).freeze

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

  def deficiency_report_template?
    DEFICIENCY_REPORT_EMAIL_TEMPLATES.include?([mailer_class, mailer_action])
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

    rendered = Liquid::Template.parse(body).render(variables.stringify_keys)

    Rinku.auto_link(rendered, :urls, 'target="_blank"')
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
