class SiteCustomization::EmailTemplate < ApplicationRecord
  self.table_name = "site_customization_email_templates"

  EMAIL_TEMPLATES = {
    "Mailer#budget_investment_created" => {
      variables: %w[recipient_greeting investment_title projekt_title investment_url],
      hidden_variables: %w[username]
    },
    "Mailer#budget_investment_feasible" => {
      variables: %w[recipient_greeting investment_title projekt_title feasibility_explanation investment_url],
      hidden_variables: %w[username]
    },
    "Mailer#budget_investment_unfeasible" => {
      variables: %w[recipient_greeting investment_title projekt_title unfeasibility_explanation
                    investment_url],
      hidden_variables: %w[username]
    },
    "Mailer#budget_investment_selected" => {
      variables: %w[recipient_greeting investment_title investment_url],
      hidden_variables: %w[username]
    },
    "Mailer#budget_investment_unselected" => {
      variables: %w[recipient_greeting investment_title investment_url projekt_title],
      hidden_variables: %w[username]
    },
    "Mailer#budget_investment_preselected" => {
      variables: %w[recipient_greeting investment_title investment_url projekt_title],
      hidden_variables: %w[username]
    },
    "Mailer#budget_investment_not_preselected" => {
      variables: %w[recipient_greeting investment_title investment_url projekt_title],
      hidden_variables: %w[username]
    },
    "Mailer#proposal_created" => {
      variables: %w[recipient_greeting proposal_title proposal_url],
      hidden_variables: %w[username]
    },
    "Mailer#proposal_official_answer" => {
      variables: %w[recipient_greeting proposal_title official_answer proposal_url],
      hidden_variables: %w[username]
    },
    "Mailer#formular_answer_created" => {
      variables: %w[recipient_greeting projekt_title phase_title],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_proposal" => {
      variables: %w[recipient_greeting proposal_title proposal_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_poll" => {
      variables: %w[recipient_greeting poll_title poll_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_comment" => {
      variables: %w[recipient_greeting comment_body comment_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#projekt_questions" => {
      variables: %w[recipient_greeting phase_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#projekt_arguments" => {
      variables: %w[recipient_greeting phase_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_projekt_notification" => {
      variables: %w[recipient_greeting phase_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_projekt_event" => {
      variables: %w[recipient_greeting phase_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_projekt_milestone" => {
      variables: %w[recipient_greeting phase_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_projekt_livestream" => {
      variables: %w[recipient_greeting phase_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_budget_investment" => {
      variables: %w[recipient_greeting investment_title investment_url projekt_title projekt_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#user_reverification_failed" => {
      variables: %w[recipient_greeting base_url],
      hidden_variables: %w[last_name]
    },
    "NotificationServiceMailer#user_reverification_succeeded" => {
      variables: %w[recipient_greeting],
      hidden_variables: %w[last_name]
    },
    "Mailer#comment" => {
      variables: %w[recipient_greeting commenter_name commentable_title commentable_url comment_body],
      hidden_variables: %w[username]
    },
    "Mailer#reply" => {
      variables: %w[recipient_greeting reply_body comment_url],
      hidden_variables: %w[username]
    },
    "Mailer#direct_message_for_receiver" => {
      variables: %w[recipient_greeting sender_name message_title message_body sender_url],
      hidden_variables: %w[username]
    },
    "Mailer#resource_hidden" => {
      variables: %w[recipient_greeting resource_text],
      hidden_variables: %w[username]
    },
    "Mailer#already_confirmed" => {
      variables: %w[recipient_greeting new_password_url],
      hidden_variables: %w[username]
    },
    "Mailer#manual_verification_confirmation" => {
      variables: %w[recipient_greeting],
      hidden_variables: %w[username]
    },
    "Mailer#newsletter_subscription_for_existing_user" => {
      variables: %w[recipient_greeting account_url],
      hidden_variables: %w[username]
    },
    "Mailer#user_invite" => {
      variables: %w[org_name registration_url]
    },
    "Mailer#pending_role_invite" => {
      variables: %w[org_name role_name registration_url]
    },
    "Mailer#csv_download_ready" => {
      variables: %w[recipient_greeting download_url],
      hidden_variables: %w[username]
    },
    "Mailer#file_ready" => {
      variables: %w[recipient_greeting file_name],
      hidden_variables: %w[username]
    },
    "Mailer#individual_group_value_users_added" => {
      variables: %w[recipient_greeting group_name group_value_name],
      hidden_variables: %w[username]
    },
    "Mailer#existing_stamp_notify_existing_user" => {
      variables: %w[recipient_greeting],
      hidden_variables: %w[username]
    },
    "Mailer#existing_stamp_notify_new_user" => {
      variables: %w[]
    },
    "Mailer#user_verification_failed" => {
      variables: %w[recipient_greeting verification_url],
      hidden_variables: %w[username]
    },
    "DeficiencyReportMailer#notify_author_about_status_change" => {
      variables: %w[recipient_greeting deficiency_report_title deficiency_report_url status_name
                    status_notice_text],
      hidden_variables: %w[username]
    },
    "DeficiencyReportMailer#notify_author_about_official_answer" => {
      variables: %w[recipient_greeting deficiency_report_title deficiency_report_url official_answer],
      hidden_variables: %w[username]
    },
    "DeficiencyReportMailer#notify_officer" => {
      variables: %w[deficiency_report_id deficiency_report_title deficiency_report_url]
    },
    "DeficiencyReportMailer#notify_default_officer_group_email" => {
      variables: %w[deficiency_report_id deficiency_report_title deficiency_report_url]
    },
    "DeficiencyReportMailer#notify_author_about_submission" => {
      variables: %w[recipient_greeting deficiency_report_title deficiency_report_url account_url],
      hidden_variables: %w[username]
    },
    "DeficiencyReportMailer#send_feedback_form_link" => {
      variables: %w[recipient_greeting deficiency_report_title deficiency_report_url status_name
                    feedback_form_url],
      hidden_variables: %w[username]
    },
    "DeficiencyReportMailer#notify_shared_report" => {
      variables: %w[recipient_greeting shared_by_name deficiency_report_id deficiency_report_title
                    deficiency_report_url unwatch_url],
      hidden_variables: %w[username]
    },
    "DeficiencyReportMailer#notify_watcher_about_change" => {
      variables: %w[recipient_greeting deficiency_report_id deficiency_report_title deficiency_report_url
                    unwatch_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_deficiency_report" => {
      variables: %w[recipient_greeting deficiency_report_id deficiency_report_title deficiency_report_url],
      hidden_variables: %w[username]
    },
    "NotificationServiceMailer#new_comments_for_deficiency_report" => {
      variables: %w[deficiency_report_title deficiency_report_url comment_count]
    },
    "NotificationServiceMailer#overdue_deficiency_reports" => {
      variables: %w[recipient_greeting overdue_count],
      hidden_variables: %w[officer_name]
    },
    "NotificationServiceMailer#overdue_deficiency_reports_overview" => {
      variables: %w[recipient_greeting overdue_count fresh_count],
      hidden_variables: %w[officer_name]
    },
    "NotificationServiceMailer#not_assigned_deficiency_reports" => {
      variables: %w[recipient_greeting not_assigned_count],
      hidden_variables: %w[admin_name]
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
    ["Mailer", "proposal_official_answer"],
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
      ["DeficiencyReportMailer", "notify_author_about_official_answer"],
      ["DeficiencyReportMailer", "send_feedback_form_link"]
    ],
    internal: [
      ["NotificationServiceMailer", "new_deficiency_report"],
      ["DeficiencyReportMailer", "notify_officer"],
      ["DeficiencyReportMailer", "notify_default_officer_group_email"],
      ["DeficiencyReportMailer", "notify_shared_report"],
      ["DeficiencyReportMailer", "notify_watcher_about_change"],
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

  def hidden_variables
    EMAIL_TEMPLATES.dig(template_key, :hidden_variables) || []
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
    templates = where(projekt_phase: projekt_phase, mailer_class: mailer_class, mailer_action: mailer_action)
                  .index_by { |template| template.locale.to_s }

    [locale, I18n.default_locale].map(&:to_s).uniq
                                 .filter_map { |candidate| templates[candidate] }
                                 .find(&:customized?)
  end

  private

    def template_key_must_be_registered
      unless EMAIL_TEMPLATES.key?(template_key)
        errors.add(:mailer_action, :not_registered)
      end
    end
end
