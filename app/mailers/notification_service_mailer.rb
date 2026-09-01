class NotificationServiceMailer < ApplicationMailer
  include CustomizableEmail
  helper TextWithLinksHelper
  helper :mailer

  def overdue_deficiency_reports(officer_id, overdue_reports_ids)
    @officer = DeficiencyReport::Officer.find(officer_id)
    @overdue_reports = DeficiencyReport.where(id: overdue_reports_ids)

    with_user(@officer.user) do
      mail_with_custom_template(nil, {
        "officer_name" => @officer.name,
        "overdue_count" => @overdue_reports.count
      }, to: @officer.email,
        default_subject: t("custom.notification_service_mailers.overdue_deficiency_reports.subject"))
    end
  end

  # The platform-wide escalation digest for officers who manage all Anliegen, so stuck cases stay
  # visible beyond the individually responsible officer.
  def overdue_deficiency_reports_overview(officer_id, overdue_reports_ids, fresh_reports_ids = [])
    @officer = DeficiencyReport::Officer.find(officer_id)
    return if @officer.user.blank?

    @fresh_reports_ids = Array(fresh_reports_ids)

    # Today's arrivals lead the list — partition rather than sort_by, so the order inside each group
    # is left alone (Ruby's sort_by is not stable).
    fresh, carried_over = DeficiencyReport.where(id: overdue_reports_ids)
                                          .includes(:responsible, :translations)
                                          .partition { |report| @fresh_reports_ids.include?(report.id) }
    @overdue_reports = fresh + carried_over

    with_user(@officer.user) do
      mail_with_custom_template(nil, {
        "officer_name" => @officer.name,
        "overdue_count" => @overdue_reports.count,
        "fresh_count" => @fresh_reports_ids.size
      }, to: @officer.email,
        default_subject: t("custom.notification_service_mailers.overdue_deficiency_reports_overview.subject"))
    end
  end

  def new_comments_for_deficiency_report(deficiency_report, last_notified_time, initial: false)
    @deficiency_report = deficiency_report
    @officer = @deficiency_report.officer
    @new_comments = @deficiency_report.comments.where("created_at > ?", last_notified_time)
    @initial = initial

    with_user(@officer.user) do
      mail_with_custom_template(nil, {
        "deficiency_report_title" => @deficiency_report.title,
        "deficiency_report_url" => deficiency_report_url(@deficiency_report),
        "comment_count" => @new_comments.count
      }, to: @officer.email,
        default_subject: t(
          "custom.notification_service_mailers.new_comments_for_deficiency_report.subject",
          deficiency_report_title: @deficiency_report.title.truncate(30)
        ))
    end
  end

  def not_assigned_deficiency_reports(admin_id, not_assigned_reports_ids)
    @admin = Administrator.find(admin_id)
    @not_assigned_reports = DeficiencyReport.where(id: not_assigned_reports_ids)

    with_user(@admin.user) do
      mail_with_custom_template(nil, {
        "admin_name" => @admin.name,
        "not_assigned_count" => @not_assigned_reports.count
      }, to: @admin.email,
        default_subject: t("custom.notification_service_mailers.not_assigned_deficiency_reports.subject"))
    end
  end

  def new_proposal(user_id, proposal_id)
    @user = User.find(user_id)
    @proposal = Proposal.find(proposal_id)
    @projekt_phase = @proposal&.projekt_phase

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "proposal_title" => @proposal.title,
        "proposal_url" => proposal_url(@proposal)
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_proposal.subject"))
    end
  end

  def new_debate(user_id, debate_id)
    @user = User.find(user_id)
    @debate = Debate.find(debate_id)
    @projekt_phase = @debate&.projekt_phase

    subject = t("custom.notification_service_mailers.new_debate.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_poll(user_id, poll_id)
    @user = User.find(user_id)
    @poll = Poll.find(poll_id)
    @projekt_phase = @poll&.projekt_phase

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "poll_title" => @poll.title,
        "poll_url" => poll_url(@poll)
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_poll.subject"))
    end
  end

  def new_comment(user_id, comment_id)
    @user = User.find(user_id)
    @comment = Comment.find(comment_id)
    @projekt_phase = @comment&.commentable if @comment&.commentable.is_a?(ProjektPhase)

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "comment_body" => @comment.body.truncate(100),
        "comment_url" => comment_url(@comment)
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_comment.subject"))
    end
  end

  def new_deficiency_report(user_id, deficiency_report_id)
    @user = User.find(user_id)
    @deficiency_report = DeficiencyReport.find(deficiency_report_id)

    with_user(@user) do
      mail_with_custom_template(nil, {
        "username" => @user.username,
        "deficiency_report_id" => @deficiency_report.id,
        "deficiency_report_title" => @deficiency_report.title,
        "deficiency_report_url" => deficiency_report_url(@deficiency_report)
      }, to: @user.email,
        default_subject: t("custom.notification_service_mailers.new_deficiency_report.subject",
                           identifier: "#{@deficiency_report.id}: #{@deficiency_report.title.first(50)}"))
    end
  end

  def new_manual_verification_request(user_to_notify_id, user_to_verify_id)
    @user_to_notify = User.find(user_to_notify_id)
    @user_to_verify = User.find(user_to_verify_id)

    subject = t("custom.notification_service_mailers.new_manual_verification_request.subject")

    with_user(@user_to_notify) do
      mail(to: @user_to_notify.email, subject: subject)
    end
  end

  def projekt_questions(user_id, projekt_phase_id)
    @user = User.find(user_id)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "phase_url" => @url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.projekt_questions.subject"))
    end
  end

  def projekt_arguments(user_id, projekt_phase_id)
    @user = User.find(user_id)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "phase_url" => @url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.projekt_arguments.subject"))
    end
  end

  def new_budget_investment(user_id, investment_id)
    @user = User.find(user_id)
    @investment = Budget::Investment.find(investment_id)
    @projekt = @investment&.projekt
    @projekt_phase = @investment.budget&.projekt_phase

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "investment_title" => @investment.title,
        "investment_url" => budget_investment_url(@investment.budget, @investment),
        "projekt_title" => @projekt&.name,
        "projekt_url" => @projekt&.page ? page_url(@projekt.page.slug) : ""
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_budget_investment.subject"))
    end
  end

  def new_projekt_notification(user_id, projekt_notification_id)
    @user = User.find(user_id)
    @projekt_notification = ProjektNotification.find(projekt_notification_id)
    @projekt_phase = @projekt_notification.projekt_phase
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "phase_url" => @url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_projekt_notification.subject"))
    end
  end

  def new_projekt_event(user_id, projekt_event_id)
    @user = User.find(user_id)
    @projekt_event = ProjektEvent.find(projekt_event_id)
    @projekt_phase = @projekt_event.projekt_phase
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "phase_url" => @url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_projekt_event.subject"))
    end
  end

  def new_projekt_milestone(user_id, projekt_milestone_id)
    @user = User.find(user_id)
    @projekt_milestone = Milestone.find(projekt_milestone_id)

    if @projekt_milestone.milestoneable.is_a?(ProjektPhase)
      @projekt_phase = @projekt_milestone.milestoneable
      @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")
    else
      return
    end

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "phase_url" => @url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_projekt_milestone.subject"))
    end
  end

  def new_projekt_livestream(user_id, projekt_livestream_id)
    @user = User.find(user_id)
    @projekt_livestream = ProjektLivestream.find(projekt_livestream_id)
    @projekt_phase = @projekt_livestream.projekt_phase
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    with_user(@user) do
      mail_with_custom_template(@projekt_phase, {
        "username" => @user.username,
        "phase_url" => @url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.new_projekt_livestream.subject"))
    end
  end

  def user_reverification_failed(user_id)
    @user = User.find(user_id)
    return if @user.email.blank?

    @base_url = Setting["url"]

    with_user(@user) do
      mail_with_custom_template(nil, {
        "last_name" => @user.last_name,
        "base_url" => @base_url
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.user_reverification_failed.subject"))
    end
  end

  def user_reverification_succeeded(user_id)
    @user = User.find(user_id)

    with_user(@user) do
      mail_with_custom_template(nil, {
        "last_name" => @user.last_name
      }, to: @user.email, default_subject: t("custom.notification_service_mailers.user_reverification_succeeded.subject"))
    end
  end

  def new_topic(user_id, community_id, topic_id)
    @user = User.find(user_id)
    @community = Community.find(community_id)
    @topic = Topic.find(topic_id)

    subject = t("custom.notification_service_mailers.new_topic.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_proposal_notification(user_id, proposal_notification_id)
    @user = User.find(user_id)
    @proposal_notification = ProposalNotification.find(proposal_notification_id)
    @proposal = @proposal_notification.proposal

    subject = t("custom.notification_service_mailers.new_proposal_notification.subject", proposal_title: @proposal.title)

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def memo(memo_id, user_id, namespace)
    @user = User.find(user_id)
    @memo = Memo.find(memo_id)
    @root_memoable = @memo.root_memoable

    @root_memoable_url = if @root_memoable.is_a?(Budget::Investment)
                           polymorphic_url([namespace, @root_memoable.budget, @root_memoable])
                         else
                           polymorphic_url([namespace, @root_memoable])
                         end

    subject = t("custom.notification_service_mailers.memo.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_projekt(user_id, projekt_id)
    @user = User.find(user_id)
    @projekt = Projekt.find(projekt_id)

    subject = t("custom.notification_service_mailers.new_projekt.subject", projekt_title: @projekt.title)

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  private

    def with_user(user)
      I18n.with_locale(user.locale) do
        yield
      end
    end
end
