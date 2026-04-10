class Adm::Moderation::HomeController < Adm::Moderation::BaseController
  def show
    authorize [:adm, :moderation, User]

    @team_members = Moderator.includes(user: :image).order(:id)
    @recent_items = Activity.includes(:user).order(created_at: :desc).limit(10)

    @section_setting = SectionSetting.for_section("moderation")
    @contact_persons = SectionContactPerson.for_section("moderation")
    @activities = SectionActivity.for_section("moderation").limit(10)

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

    @quick_links = [
      { label: t("adm.moderation.home.quick_links.all"), path: adm_moderation_proposals_path }
    ]

    @breadcrumbs = [
      { name: t("adm.moderation.home.title"), icon: "home" }
    ]
  end
end
