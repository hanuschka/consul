class Adm::Moderation::HomeController < Adm::Moderation::BaseController
  def show
    authorize [:adm, :moderation, User]

    @team_members = Moderator.includes(user: :image).order(:id)

    @intro_text = Setting["adm.moderation.intro_text"].presence ||
                  I18n.t("adm.section_settings.intro_text_defaults.moderation", default: nil)
    @notice_active = Setting["adm.moderation.notice_active"].present?
    @notice_message = Setting["adm.moderation.notice_message"]
    @contact_persons = SectionContactPerson.for_section("moderation")
    @pagy_activities, @activities = pagy(SectionActivity.for_section("moderation"), limit: 10, page_param: :activity_page)

    pending_count = Proposal.pending_flag_review.count +
                    Comment.pending_flag_review.count +
                    Budget::Investment.pending_flag_review.count
    blocked_count = User.only_deleted.count
    moderated_count = Proposal.only_deleted.count +
                      Comment.only_deleted.count +
                      Budget::Investment.only_deleted.count

    @stats = [
      { value: pending_count, label: t("adm.moderation.home.stats.pending"), icon: "pending" },
      { value: blocked_count, label: t("adm.moderation.home.stats.blocked_users"), icon: "block" },
      { value: moderated_count, label: t("adm.moderation.home.stats.moderated_total"), icon: "verified_user" }
    ]

    @quick_links = []

    @tiles_title = t("adm.moderation.home.tiles.title")
    @tiles_hint  = t("adm.moderation.home.tiles.hint")
    @tiles = [
      {
        path: adm_moderation_proposals_path,
        icon: "lightbulb",
        title: t("adm.moderation.home.tiles.proposals.title"),
        metric_text: t("adm.moderation.home.tiles.proposals.metric",
                       count: Proposal.pending_flag_review.count)
      },
      {
        path: adm_moderation_comments_path,
        icon: "forum",
        title: t("adm.moderation.home.tiles.comments.title"),
        metric_text: t("adm.moderation.home.tiles.comments.metric",
                       count: Comment.pending_flag_review.count)
      },
      {
        path: adm_moderation_budget_investments_path,
        icon: "savings",
        title: t("adm.moderation.home.tiles.budget_investments.title"),
        metric_text: t("adm.moderation.home.tiles.budget_investments.metric",
                       count: Budget::Investment.pending_flag_review.count)
      },
      {
        path: adm_moderation_users_path,
        icon: "person_off",
        title: t("adm.moderation.home.tiles.users.title"),
        metric_text: t("adm.moderation.home.tiles.users.metric",
                       count: User.only_deleted.count)
      }
    ]

    @breadcrumbs = [
      { name: t("adm.moderation.menu.items.home"), icon: "home" }
    ]
  end
end
