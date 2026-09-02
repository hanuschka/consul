class Adm::Projekts::ProposalsController < Adm::Projekts::BaseController
  before_action :find_projekt_phase
  before_action :find_proposal

  def show
    authorize [:adm, @proposal]

    respond_to do |format|
      format.html do
        @breadcrumbs = [
          { name: @projekt_phase.projekt.name, url: details_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title, url: proposals_adm_projekts_phase_path(@projekt_phase) },
          { name: @proposal.title }
        ]

        @image_url = @proposal.image&.attachment_variant(
          resize_to_limit: [500, 500],
          format: "jpeg"
        )
      end
      format.pdf do
        pdf_content = PdfServices::ProposalExporter.call(@proposal, request.host)
        send_data pdf_content.render, filename: "proposal_#{@proposal.id}.pdf", type: "application/pdf", disposition: "inline"
      end
    end
  end

  def hide
    authorize [:adm, @proposal], :hide?

    @proposal.hide
    Activity.log(current_user, :hide, @proposal)
    @proposal.reload
  end

  def ignore_flag
    authorize [:adm, @proposal], :ignore_flag?

    @proposal.ignore_flag
    @proposal.reload
  end

  def unhide
    authorize [:adm, @proposal], :unhide?

    @proposal.restore
    Activity.log(current_user, :restore, @proposal)
    @proposal.reload
  end

  def toggle_admin_accepted
    authorize [:adm, @proposal], :toggle_admin_accepted?

    @proposal.update!(proposal_params)
  end

  def update_official_answer
    authorize [:adm, @proposal], :update?

    if @proposal.update(proposal_params)
      flash.now[:success] = t(".success")
    end

    render turbo_stream: turbo_stream.replace(
      helpers.dom_id(@proposal, :official_answer),
      Adm::AttributeEditorComponent.new(
        @proposal,
        :official_answer,
        :rich_text,
        path: update_official_answer_adm_projekts_phase_proposal_path(@projekt_phase, @proposal),
        label: t(".official_answer"),
        description: t(".official_answer_hint")
      )
    )
  end

  private

    def find_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def find_proposal
      @proposal = @projekt_phase.proposals.with_hidden.find(params[:id])
    end

    def proposal_params
      params.require(:proposal).permit(:admin_accepted, :official_answer)
    end
end
