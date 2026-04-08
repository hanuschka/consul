class Adm::Moderation::ProposalsController < Adm::Moderation::BaseController
  FILTERS = %w[pending_flag_review with_ignored_flag hidden all].freeze

  def index
    authorize [:adm, :moderation, Proposal]
    base_scope = policy_scope([:adm, :moderation, Proposal])
    @current_filter = FILTERS.include?(params[:filter]) ? params[:filter] : FILTERS.first
    base_scope = apply_filter(base_scope)
    @pagy, @proposals = pagy(ProposalsQuery.call(base_scope, params))

    @title_header_options = { search: true }
    @flags_count_header_options = { sort: true }

    @breadcrumbs = [
      { name: I18n.t("adm.moderation.menu.title"), icon: "article" },
      { name: I18n.t("adm.moderation.menu.proposals") }
    ]
  end

  def hide
    @proposal = Proposal.find(params[:id])
    authorize [:adm, :moderation, @proposal], :hide?

    @proposal.hide
    Activity.log(current_user, :hide, @proposal)
    @proposal.reload
  end

  def ignore_flag
    @proposal = Proposal.find(params[:id])
    authorize [:adm, :moderation, @proposal], :ignore_flag?

    @proposal.ignore_flag
    @proposal.reload
  end

  private

    def apply_filter(scope)
      case @current_filter
      when "pending_flag_review"
        scope.pending_flag_review
      when "with_ignored_flag"
        scope.with_ignored_flag
      when "hidden"
        scope.only_hidden
      else
        scope
      end
    end
end
