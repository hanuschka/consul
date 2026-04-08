class Adm::Projekts::Milestones::BaseController < Adm::Projekts::BaseController
  include ImageAttributes

  before_action :set_projekt_phase
  before_action :set_milestoneable
  before_action :set_milestone, only: %i[edit update destroy]

  LOCALE_SCOPE = "adm.projekts.milestones"

  def new
    @milestone = @milestoneable.milestones.new
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    @statuses = Milestone::Status.all
    @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.new.title"))
    render "adm/projekts/milestones/new"
  end

  def create
    @milestone = @milestoneable.milestones.new(milestone_params)
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    if @milestone.save
      after_create(@milestone)
      redirect_to milestones_index_url, notice: t("#{LOCALE_SCOPE}.create.success")
    else
      @statuses = Milestone::Status.all
      @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.new.title"))
      render "adm/projekts/milestones/new", status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    @statuses = Milestone::Status.all
    @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.edit.title"))
    render "adm/projekts/milestones/edit"
  end

  def update
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    if @milestone.update(milestone_params)
      redirect_to milestones_index_url, notice: t("#{LOCALE_SCOPE}.update.success")
    else
      @statuses = Milestone::Status.all
      @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.edit.title"))
      render "adm/projekts/milestones/edit", status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @milestone], policy_class: Adm::Projekts::MilestonePolicy

    @milestone.destroy!
    redirect_to milestones_index_url, notice: t("#{LOCALE_SCOPE}.destroy.success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    # Override in subclasses
    def set_milestoneable
      raise NotImplementedError
    end

    def set_milestone
      @milestone = @milestoneable.milestones.find(params[:id])
    end

    def after_create(milestone)
      # Override in subclasses if needed
    end

    def milestone_params
      params.require(:milestone).permit(
        :publication_date, :status_id, :description, :custom_date,
        image_attributes: image_attributes
      )
    end

    # Override in subclasses
    def milestones_index_url
      raise NotImplementedError
    end

    def new_milestone_url
      raise NotImplementedError
    end

    def edit_milestone_url(milestone)
      raise NotImplementedError
    end

    def delete_milestone_url(milestone)
      raise NotImplementedError
    end

    def milestones_create_url
      milestones_index_url
    end

    def milestone_update_url(milestone)
      raise NotImplementedError
    end

    helper_method :milestones_index_url, :milestones_create_url, :milestone_update_url,
                  :new_milestone_url, :edit_milestone_url, :delete_milestone_url

    # Override in subclasses
    def breadcrumbs_for_action(action_title)
      raise NotImplementedError
    end
end
