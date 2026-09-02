class Mailer < ApplicationMailer
  include ActionView::Helpers::TranslationHelper
  include CustomizableEmail

  after_action :prevent_delivery_to_users_without_email

  helper :text_with_links
  helper :mailer
  helper :users

  def comment(comment)
    @comment = comment
    @commentable = comment.commentable
    @email_to = @commentable.author.email
    manage_subscriptions_token(@commentable.author)

    return unless @commentable.present? && @commentable.author.present?

    with_user(@commentable.author) do
      mail_with_custom_template(nil, {
        "username" => @commentable.author.username,
        "commenter_name" => @comment.author.name,
        "commentable_title" => @commentable.title,
        "commentable_url" => polymorphic_url(@commentable),
        "comment_body" => @comment.body.truncate(200)
      }, to: @email_to, default_subject: t("mailers.comment.subject", commentable: t("activerecord.models.#{@commentable.class.name.underscore}", count: 1).downcase))
    end
  end

  def reply(reply)
    @reply = reply
    @email = ReplyEmail.new(reply)
    @email_to = @email.to
    manage_subscriptions_token(@email.recipient)

    return unless @email.can_be_sent?

    with_user(@email.recipient) do
      mail_with_custom_template(nil, {
        "username" => @email.recipient.username,
        "reply_body" => @reply.body.truncate(200),
        "comment_url" => comment_url(@reply)
      }, to: @email_to, default_subject: @email.subject)
    end
  end

  def email_verification(user, recipient, token, document_type, document_number)
    @user = user
    @email_to = recipient
    @token = token
    @document_type = document_type
    @document_number = document_number

    with_user(user) do
      mail(to: @email_to, subject: t("mailers.email_verification.subject"))
    end
  end

  def direct_message_for_receiver(direct_message)
    @direct_message = direct_message
    @receiver = @direct_message.receiver
    @email_to = @receiver.email
    manage_subscriptions_token(@receiver)

    with_user(@receiver) do
      mail_with_custom_template(nil, {
        "username" => @receiver.username,
        "sender_name" => @direct_message.sender.name,
        "message_title" => @direct_message.title,
        "message_body" => @direct_message.body.truncate(200),
        "sender_url" => user_url(@direct_message.sender)
      }, to: @email_to, default_subject: t("mailers.direct_message_for_receiver.subject"))
    end
  end

  def direct_message_for_sender(direct_message)
    @direct_message = direct_message
    @sender = @direct_message.sender
    @email_to = @sender.email

    with_user(@sender) do
      mail(to: @email_to, subject: t("mailers.direct_message_for_sender.subject"))
    end
  end

  def proposal_notification_digest(user, notifications)
    @notifications = notifications
    @email_to = user.email
    manage_subscriptions_token(user)

    with_user(user) do
      mail(to: @email_to, subject: t("mailers.proposal_notification_digest.title", org_name: Setting["org_name"]))
    end
  end

  def user_invite(email)
    @email_to = email

    I18n.with_locale(I18n.default_locale) do
      mail_with_custom_template(nil, {
        "org_name" => Setting["org_name"],
        "registration_url" => new_user_registration_url
      }, to: @email_to, default_subject: t("mailers.user_invite.subject", org_name: Setting["org_name"]))
    end
  end

  def pending_role_invite(pending_role_assignment)
    @pending_role_assignment = pending_role_assignment
    @email_to = pending_role_assignment.email
    @role_name = I18n.t("mailers.pending_role_invite.roles.#{pending_role_assignment.role_type.underscore}",
                        default: pending_role_assignment.role_type.titleize)

    I18n.with_locale(I18n.default_locale) do
      mail_with_custom_template(nil, {
        "org_name" => Setting["org_name"],
        "role_name" => @role_name,
        "registration_url" => new_user_registration_url(invitation_token: pending_role_assignment.invitation_token)
      }, to: @email_to, default_subject: t("mailers.pending_role_invite.subject", role: @role_name))
    end
  end

  def proposal_created(proposal)
    @proposal = proposal
    @author = @proposal.author
    @email_to = @proposal.author.email

    with_user(@proposal.author) do
      mail_with_custom_template(proposal.projekt_phase, {
        "username" => @author.username,
        "proposal_title" => @proposal.title,
        "proposal_url" => proposal_url(@proposal)
      }, to: @email_to, default_subject: t("mailers.proposal_created.subject"))
    end
  end

  def proposal_official_answer(proposal)
    @proposal = proposal
    @author = @proposal.author
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(nil, {
        "username" => @author.username,
        "proposal_title" => @proposal.title,
        "official_answer" => @proposal.official_answer,
        "proposal_url" => proposal_url(@proposal)
      }, to: @email_to, default_subject: t("mailers.proposal_official_answer.subject"))
    end
  end

  def budget_investment_created(investment)
    @investment = investment
    @projekt = investment.projekt
    @email_to = @investment.author.email

    with_user(@investment.author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @investment.author.username,
        "investment_title" => @investment.title,
        "projekt_title" => @projekt&.name,
        "investment_url" => budget_investment_url(@investment.budget, @investment)
      }, to: @email_to, default_subject: t("mailers.budget_investment_created.subject"))
    end
  end

  def budget_investment_unfeasible(investment)
    @investment = investment
    @projekt = investment.projekt
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @author.username,
        "investment_title" => @investment.title,
        "projekt_title" => @projekt&.name,
        "unfeasibility_explanation" => @investment.unfeasibility_explanation
      }, to: @email_to, default_subject: t("mailers.budget_investment_unfeasible.subject"))
    end
  end

  def budget_investment_feasible(investment)
    @investment = investment
    @projekt = investment.projekt
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @author.username,
        "investment_title" => @investment.title,
        "projekt_title" => @projekt&.name
      }, to: @email_to, default_subject: t("mailers.budget_investment_feasible.subject"))
    end
  end

  def budget_investment_selected(investment)
    @investment = investment
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @author.username,
        "investment_title" => @investment.title,
        "investment_url" => budget_investment_url(@investment.budget, @investment)
      }, to: @email_to, default_subject: t("mailers.budget_investment_selected.subject"))
    end
  end

  def budget_investment_unselected(investment)
    @investment = investment
    @author = investment.author
    @projekt = investment.projekt
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @author.username,
        "investment_title" => @investment.title,
        "investment_url" => budget_investment_url(@investment.budget, @investment),
        "projekt_title" => @projekt&.name
      }, to: @email_to, default_subject: t("mailers.budget_investment_unselected.subject"))
    end
  end

  def newsletter(newsletter, recipient_email)
    @newsletter = newsletter
    @email_to = recipient_email

    user = User.find_by(email: @email_to)

    if user.present?
      manage_subscriptions_token(user)
    end

    if Setting["advanced_newsletter"].present?
      mail(to: @email_to, from: @newsletter.from, subject: @newsletter.subject) do |f|
        f.html { render(layout: "newsletter_mail") }
      end
    else
      mail(to: @email_to, from: @newsletter.from, subject: @newsletter.subject) do |f|
        f.html { render("mailer/newsletter_simple", layout: "mailer") }
      end
    end
  end

  def evaluation_comment(comment, to)
    @email = EvaluationCommentEmail.new(comment)
    @email_to = to

    mail(to: @email_to.email, subject: @email.subject) if @email.can_be_sent?
  end

  def machine_learning_error(user)
    @email_to = user.email

    mail(to: @email_to, subject: t("mailers.machine_learning_error.subject"))
  end

  def machine_learning_success(user)
    @email_to = user.email

    mail(to: @email_to, subject: t("mailers.machine_learning_success.subject"))
  end

  def already_confirmed(user)
    @email_to = user.email
    @user = user

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "new_password_url" => new_user_password_url
      }, to: @email_to, default_subject: t("mailers.already_confirmed.subject"))
    end
  end

  def manual_verification_confirmation(user)
    @email_to = user.email
    @user = user

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username
      }, to: @email_to, default_subject: t("mailers.manual_verification_confirmation.subject"))
    end
  end

  def formular_answer_created(formular_answer)
    @formular_answer = formular_answer
    @author = User.find_by(id: formular_answer.submitter_id)
    return if @author.blank?

    @email_to = @author.email
    @projekt_phase = formular_answer.formular.projekt_phase

    with_user(@author) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @author.username,
        "projekt_title" => @projekt_phase.projekt.page.title,
        "phase_title" => @projekt_phase.title
      }, to: @email_to, default_subject: t("mailers.formular_answer_created.subject"))
    end
  end

  def formular_answer_confirmation(formular_answer)
    @email_to = formular_answer.email_address
    return if @email_to.blank?

    @email_subject = formular_answer.email_subject || t("mailers.formular_answer_confirmation.subject")
    @email_text = formular_answer.email_text
    mail(to: @email_to, subject: @email_subject)
  end

  def formular_follow_up_letter(follow_up_letter, recipient)
    @follow_up_letter = follow_up_letter
    @recipient = recipient
    @projekt_phase = follow_up_letter.formular.projekt_phase

    @email_to = @recipient.email
    mail(to: @email_to, subject: @follow_up_letter.subject)
  end

  def newsletter_subscription_for_existing_user(user)
    @email_to = user.email
    @user = user

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "account_url" => account_url
      }, to: @email_to, default_subject: t("mailers.newsletter_subscription_for_existing_user.subject"))
    end
  end

  def csv_download_ready(user, download_url)
    @email_to = user.email
    @user = user
    @download_url = download_url

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "download_url" => @download_url
      }, to: @email_to, default_subject: t("mailers.csv_download_ready.subject"))
    end
  end

  def file_ready(user, file_name, file_path)
    @email_to = user.email
    @user = user
    @file_name = file_name
    @file_path = Rails.root.join(file_path)

    with_user(@user) do
      attachments[@file_name] = File.read(@file_path)
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "file_name" => @file_name
      }, to: @email_to, default_subject: t("mailers.file_ready.subject"))
    end
  end

  def individual_group_value_users_added(user_id, individual_group_value_id)
    @user = User.find(user_id)
    @email_to = @user.email
    @individual_group_value = IndividualGroupValue.find(individual_group_value_id)
    @individual_group = @individual_group_value.individual_group

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "group_name" => @individual_group.name,
        "group_value_name" => @individual_group_value.name
      }, to: @email_to, default_subject: t("mailers.individual_group_value_users_added.subject"))
    end
  end

  def resource_hidden(resource)
    @resource = resource
    @resource_text = resource.is_a?(Comment) ? resource.body : resource.title
    @author = resource.author
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(nil, {
        "username" => @author.username,
        "resource_text" => @resource_text.truncate(200)
      }, to: @email_to, default_subject: t("mailers.resource_hidden.subject"))
    end
  end

  def budget_investment_preselected(investment)
    @investment = investment
    @author = investment.author
    @projekt = investment.projekt
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @author.username,
        "investment_title" => @investment.title,
        "investment_url" => budget_investment_url(@investment.budget, @investment),
        "projekt_title" => @projekt&.name
      }, to: @email_to, default_subject: t("mailers.budget_investment_preselected.subject"))
    end
  end

  def budget_investment_not_preselected(investment)
    @investment = investment
    @projekt = investment.projekt
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail_with_custom_template(investment.budget&.projekt_phase, {
        "username" => @author.username,
        "investment_title" => @investment.title,
        "investment_url" => budget_investment_url(@investment.budget, @investment),
        "projekt_title" => @projekt&.name
      }, to: @email_to, default_subject: t("mailers.budget_investment_not_preselected.subject"))
    end
  end

  def customizable_test_email(email, subject, body)
    @custom_email_subject = subject
    @custom_email_body = body
    @email_to = email

    mail(to: @email_to, subject: @custom_email_subject, template_name: "customizable_email")
  end

  def custom_mail(recipient, title, body)
    @recipient = recipient
    @subject = title
    @title = title
    @body = body
    @email_to = recipient.email

    with_user(recipient) do
      mail(to: @email_to, subject: @subject)
    end
  end

  def new_valuator_assignment(valuator_assignment)
    @investment = valuator_assignment.investment
    @recipient = valuator_assignment.valuator.user
    @email_to = @recipient.email

    with_user(@recipient) do
      mail(to: @email_to, subject: t("mailers.new_valuator_assignment.subject"))
    end
  end

  def existing_stamp_notify_existing_user(user)
    @user = user
    @email_to = @user.email

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username
      }, to: @email_to, default_subject: t("mailers.existing_stamp_notify_existing_user.subject"))
    end
  end

  def existing_stamp_notify_new_user(email)
    @email_to = email

    mail_with_custom_template(nil, {},
      to: @email_to, default_subject: t("mailers.existing_stamp_notify_new_user.subject"))
  end

  def user_verification_failed(user)
    @user = user
    @email_to = @user.email

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "verification_url" => new_residence_url
      }, to: @email_to, default_subject: t("mailers.user_verification_failed.subject"))
    end
  end

  def projekt_event_registration_confirmation_email(registration)
    @email_to = registration.email
    return if @email_to.blank?

    @registration = registration
    @event = registration.projekt_event
    @confirmation_url = confirm_projekt_event_registration_url(token: registration.confirmation_token)

    mail(to: @email_to, subject: @event.title, template_name: "projekt_event_registration_confirmation")
  end

  def projekt_event_registration_email(registration)
    @email_to = registration.email
    return if @email_to.blank?

    event = registration.projekt_event
    email_text = if registration.status == "confirmed"
                   event.confirmation_email_text
                 else
                   event.waitlist_email_text
                 end
    return if email_text.blank?

    @title = event.title
    @body = email_text

    mail(to: @email_to, subject: @title, template_name: "custom_mail")
  end

  private

    def with_user(user, &block)
      I18n.with_locale(user.locale, &block)
    end

    def prevent_delivery_to_users_without_email
      if @email_to.blank? || @email_to.include?("@example.com")
        mail.perform_deliveries = false
      end
    end

    def manage_subscriptions_token(user)
      user.add_subscriptions_token
      @subscriptions_token = user.subscriptions_token
    end
end
