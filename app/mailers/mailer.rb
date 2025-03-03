class Mailer < ApplicationMailer
  include ActionView::Helpers::TranslationHelper

  after_action :prevent_delivery_to_users_without_email

  helper :text_with_links
  helper :mailer
  helper :users

  def comment(comment)
    @comment = comment
    @commentable = comment.commentable
    @email_to = @commentable.author.email
    manage_subscriptions_token(@commentable.author)

    with_user(@commentable.author) do
      subject = t("mailers.comment.subject", commentable: t("activerecord.models.#{@commentable.class.name.underscore}", count: 1).downcase)
      mail(to: @email_to, subject: subject) if @commentable.present? && @commentable.author.present?
    end
  end

  def reply(reply)
    @reply = reply
    @email = ReplyEmail.new(reply)
    @email_to = @email.to
    manage_subscriptions_token(@email.recipient)

    with_user(@email.recipient) do
      mail(to: @email_to, subject: @email.subject) if @email.can_be_sent?
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
      mail(to: @email_to, subject: t("mailers.direct_message_for_receiver.subject"))
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
      mail(to: @email_to, subject: t("mailers.user_invite.subject", org_name: Setting["org_name"]))
    end
  end

  def budget_investment_created(investment)
    @investment = investment
    @projekt = investment.projekt
    @email_to = @investment.author.email

    with_user(@investment.author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_created.subject"))
    end
  end

  def budget_investment_unfeasible(investment)
    @investment = investment
    @projekt = investment.projekt
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_unfeasible.subject"))
    end
  end

  def budget_investment_feasible(investment)
    @investment = investment
    @projekt = investment.projekt
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_feasible.subject"))
    end
  end

  def budget_investment_selected(investment)
    @investment = investment
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_selected.subject"))
    end
  end

  def budget_investment_unselected(investment)
    @investment = investment
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_unselected.subject"))
    end
  end

  def newsletter(newsletter, recipient_email)
    @newsletter = newsletter
    @email_to = recipient_email

    user = User.find_by(email: @email_to)

    if user.present?
      manage_subscriptions_token(user)
    end

    mail(to: @email_to, from: @newsletter.from, subject: @newsletter.subject) do |f|
      f.html { render(layout: "newsletter_mail")}
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
      mail(to: @email_to, subject: t("mailers.already_confirmed.subject"))
    end
  end

  def manual_verification_confirmation(user)
    @email_to = user.email
    @user = user

    with_user(@user) do
      mail(to: @email_to, subject: t("mailers.manual_verification_confirmation.subject"))
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
      mail(to: @email_to, subject: t("mailers.newsletter_subscription_for_existing_user.subject"))
    end
  end

  def file_ready(user, file_name, file_path)
    @email_to = user.email
    @user = user
    @file_name = file_name
    @file_path = Rails.root.join(file_path)

    with_user(@user) do
      attachments[@file_name] = File.read(@file_path)
      mail(to: @email_to, subject: t("mailers.file_ready.subject"))
    end
  end

  def individual_group_value_users_added(user_id, individual_group_value_id)
    @user = User.find(user_id)
    @email_to = @user.email
    @individual_group_value = IndividualGroupValue.find(individual_group_value_id)
    @individual_group = @individual_group_value.individual_group

    with_user(@user) do
      mail(to: @email_to, subject: t("mailers.individual_group_value_users_added.subject"))
    end
  end

  def resource_hidden(resource)
    @resource = resource
    @resource_text = resource.is_a?(Comment) ? resource.body : resource.title
    @author = resource.author
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.resource_hidden.subject"))
    end
  end

  def budget_investment_preselected(investment)
    @investment = investment
    @author = investment.author
    @projekt = investment.projekt
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_preselected.subject"))
    end
  end

  def budget_investment_not_preselected(investment)
    @investment = investment
    @projekt = investment.projekt
    @author = investment.author
    @email_to = @author.email

    with_user(@author) do
      mail(to: @email_to, subject: t("mailers.budget_investment_not_preselected.subject"))
    end
  end

  private

    def with_user(user, &block)
      I18n.with_locale(user.locale, &block)
    end

    def prevent_delivery_to_users_without_email
      if @email_to.blank?
        mail.perform_deliveries = false
      end
    end

    def manage_subscriptions_token(user)
      user.add_subscriptions_token
      @subscriptions_token = user.subscriptions_token
    end
end
