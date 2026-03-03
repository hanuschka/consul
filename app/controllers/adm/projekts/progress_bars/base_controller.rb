class Adm::Projekts::ProgressBars::BaseController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_progressable
  before_action :set_progress_bar, only: %i[edit update destroy]

  LOCALE_SCOPE = "adm.projekts.progress_bars"

  def new
    @progress_bar = @progressable.progress_bars.new
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.new.title"))
    render "adm/projekts/progress_bars/new"
  end

  def create
    @progress_bar = @progressable.progress_bars.new(progress_bar_params)
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    if @progress_bar.save
      redirect_to progress_bars_index_url, notice: t("#{LOCALE_SCOPE}.create.success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.new.title"))
      render "adm/projekts/progress_bars/new", status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.edit.title"))
    render "adm/projekts/progress_bars/edit"
  end

  def update
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    if @progress_bar.update(progress_bar_params)
      redirect_to progress_bars_index_url, notice: t("#{LOCALE_SCOPE}.update.success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("#{LOCALE_SCOPE}.edit.title"))
      render "adm/projekts/progress_bars/edit", status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @progress_bar], policy_class: Adm::Projekts::ProgressBarPolicy

    @progress_bar.destroy!
    redirect_to progress_bars_index_url, notice: t("#{LOCALE_SCOPE}.destroy.success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    # Override in subclasses
    def set_progressable
      raise NotImplementedError
    end

    def set_progress_bar
      @progress_bar = @progressable.progress_bars.find(params[:id])
    end

    def progress_bar_params
      params.require(:progress_bar).permit(:kind, :percentage, :title)
    end

    # Override in subclasses
    def progress_bars_index_url
      raise NotImplementedError
    end

    def progress_bars_create_url
      progress_bars_index_url
    end

    def progress_bar_update_url(progress_bar)
      raise NotImplementedError
    end

    helper_method :progress_bars_index_url, :progress_bars_create_url, :progress_bar_update_url

    # Override in subclasses
    def breadcrumbs_for_action(action_title)
      raise NotImplementedError
    end
end
