class Adm::Projekts::FormularFieldsController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_formular
  before_action :set_formular_field, only: %i[edit update destroy]

  def new
    @formular_field = @formular.formular_fields.new
    authorize [:adm, :projekts, @formular_field], policy_class: Adm::Projekts::FormularFieldPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @formular_field = @formular.formular_fields.new(formular_field_params.merge(given_order: @formular.formular_fields.count + 1))
    authorize [:adm, :projekts, @formular_field], policy_class: Adm::Projekts::FormularFieldPolicy

    if @formular_field.save
      redirect_to formular_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.formular_fields.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @formular_field], policy_class: Adm::Projekts::FormularFieldPolicy
    @formular_field.set_custom_attributes

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @formular_field], policy_class: Adm::Projekts::FormularFieldPolicy

    if @formular_field.update(formular_field_params)
      redirect_to formular_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.formular_fields.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @formular_field], policy_class: Adm::Projekts::FormularFieldPolicy

    @formular_field.destroy!
    redirect_to formular_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  def reorder
    authorize [:adm, :projekts, @projekt_phase], :update?, policy_class: Adm::Projekts::ProjektPhasePolicy

    ordered_ids = params[:tree].map { |item| item[:id] }
    ordered_ids.each_with_index do |id, index|
      @formular.formular_fields.where(id: id).update_all(given_order: index + 1)
    end

    head :ok
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_formular
      @formular = @projekt_phase.formular
    end

    def set_formular_field
      @formular_field = @formular.formular_fields.find(params[:id])
    end

    def formular_field_params
      params.require(:formular_field).permit(
        :name, :description, :required, :kind, :follow_up,
        *FormularField::CUSTOM_ATTRIBUTES
      )
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.formular.title"), url: formular_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
