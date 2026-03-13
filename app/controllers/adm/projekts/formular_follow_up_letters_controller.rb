class Adm::Projekts::FormularFollowUpLettersController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_formular
  before_action :set_letter, only: %i[edit update destroy send_emails]

  def create
    @letter = @formular.formular_follow_up_letters.new
    @letter.formular_answer_ids = params[:formular_answer_ids]
    authorize [:adm, :projekts, @letter], policy_class: Adm::Projekts::FormularFollowUpLetterPolicy

    @letter.save!
    redirect_to edit_adm_projekts_phase_formular_follow_up_letter_path(@projekt_phase, @letter), notice: t(".success")
  end

  def edit
    authorize [:adm, :projekts, @letter], policy_class: Adm::Projekts::FormularFollowUpLetterPolicy

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @letter], policy_class: Adm::Projekts::FormularFollowUpLetterPolicy

    if @letter.update(letter_params)
      redirect_to formular_answers_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.formular_follow_up_letters.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @letter], policy_class: Adm::Projekts::FormularFollowUpLetterPolicy

    @letter.destroy!
    redirect_to formular_answers_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  def send_emails
    authorize [:adm, :projekts, @letter], policy_class: Adm::Projekts::FormularFollowUpLetterPolicy

    @letter.delay.deliver
    @letter.update!(sent_at: Time.zone.now)
    redirect_to formular_answers_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_formular
      @formular = @projekt_phase.formular
    end

    def set_letter
      @letter = @formular.formular_follow_up_letters.find(params[:id])
    end

    def letter_params
      params.require(:formular_follow_up_letter).permit(:subject, :body, :show_follow_up_button)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: t("adm.menu.items.projekts"), icon: "folder", url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.formular_answers.title"), url: formular_answers_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
