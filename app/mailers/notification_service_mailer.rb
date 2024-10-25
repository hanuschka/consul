class NotificationServiceMailer < ApplicationMailer
  helper TextWithLinksHelper

  def overdue_deficiency_reports(officer_id, overdue_reports_ids)
    @officer = DeficiencyReport::Officer.find(officer_id)
    @overdue_reports = DeficiencyReport.where(id: overdue_reports_ids)

    subject = t("custom.notification_service_mailers.overdue_deficiency_reports.subject")

    with_user(@officer.user) do
      mail(to: @officer.email, subject: subject)
    end
  end

  def new_comments_for_deficiency_report(deficiency_report, last_notified_time, initial: false)
    @deficiency_report = deficiency_report
    @officer = @deficiency_report.officer
    @new_comments = @deficiency_report.comments.where("created_at > ?", last_notified_time)
    @initial = initial

    subject = t(
      "custom.notification_service_mailers.new_comments_for_deficiency_report.subject",
      deficiency_report_title: @deficiency_report.title.truncate(30)
    )

    with_user(@officer.user) do
      mail(to: @officer.email, subject: subject)
    end
  end

  def not_assigned_deficiency_reports(admin_id, not_assigned_reports_ids)
    @admin = Administrator.find(admin_id)
    @not_assigned_reports = DeficiencyReport.where(id: not_assigned_reports_ids)

    subject = t("custom.notification_service_mailers.not_assigned_deficiency_reports.subject")

    with_user(@admin.user) do
      mail(to: @admin.email, subject: subject)
    end
  end

  def new_proposal(user_id, proposal_id)
    @user = User.find(user_id)
    @proposal = Proposal.find(proposal_id)
    @projekt_phase = @proposal&.projekt_phase

    subject = t("custom.notification_service_mailers.new_proposal.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
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

    subject = t("custom.notification_service_mailers.new_poll.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_comment(user_id, comment_id)
    @user = User.find(user_id)
    @comment = Comment.find(comment_id)
    @projekt_phase = @comment&.commentable if @comment&.commentable.is_a?(ProjektPhase)

    subject = t("custom.notification_service_mailers.new_comment.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_deficiency_report(user_id, deficiency_report_id)
    @user = User.find(user_id)
    @deficiency_report = DeficiencyReport.find(deficiency_report_id)

    subject = t("custom.notification_service_mailers.new_deficiency_report.subject",
                identifier: "#{@deficiency_report.id}: #{@deficiency_report.title.first(50)}")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
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

    subject = t("custom.notification_service_mailers.projekt_questions.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def projekt_arguments(user_id, projekt_phase_id)
    @user = User.find(user_id)
    @projekt_phase = ProjektPhase.find(projekt_phase_id)
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    subject = t("custom.notification_service_mailers.projekt_arguments.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_budget_investment(user_id, investment_id)
    @user = User.find(user_id)
    @investment = Budget::Investment.find(investment_id)
    @projekt_phase = @investment&.projekt_phase

    subject = t("custom.notification_service_mailers.new_budget_investment.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_projekt_notification(user_id, projekt_notification_id)
    @user = User.find(user_id)
    @projekt_notification = ProjektNotification.find(projekt_notification_id)
    @projekt_phase = @projekt_notification.projekt_phase
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    subject = t("custom.notification_service_mailers.new_projekt_notification.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_projekt_event(user_id, projekt_event_id)
    @user = User.find(user_id)
    @projekt_event = ProjektEvent.find(projekt_event_id)
    @projekt_phase = @projekt_event.projekt_phase
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    subject = t("custom.notification_service_mailers.new_projekt_event.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
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

    subject = t("custom.notification_service_mailers.new_projekt_milestone.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
    end
  end

  def new_projekt_livestream(user_id, projekt_livestream_id)
    @user = User.find(user_id)
    @projekt_livestream = ProjektLivestream.find(projekt_livestream_id)
    @projekt_phase = @projekt_livestream.projekt_phase
    @url = page_url(@projekt_phase.projekt.page.slug, projekt_phase_id: @projekt_phase.id, anchor: "filter-subnav")

    subject = t("custom.notification_service_mailers.new_projekt_livestream.subject")

    with_user(@user) do
      mail(to: @user.email, subject: subject)
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

  private

    def with_user(user)
      I18n.with_locale(user.locale) do
        yield
      end
    end
end
