require_dependency Rails.root.join("app", "helpers", "proposals_helper").to_s

module ProposalsHelper

  def all_proposal_map_locations
    proposals_for_map = Proposal.not_archived.published

    if params[:tags].present?
      proposals_for_map = proposals_for_map.tagged_with(params[:tags].split(","), all: true)
    end

    if params[:projekts].present?
      proposals_for_map = proposals_for_map.where(projekt_id: params[:projekts].split(',')).distinct
    end

    ids = proposals_for_map.pluck(:id).uniq

    MapLocation.where(proposal_id: ids).map(&:json_data)
  end

  def json_data
    proposal = Proposal.find(params[:id])
    data = {
      proposal_id: proposal.id,
      proposal_title: proposal.title
    }.to_json

    respond_to do |format|
      format.json { render json: data }
    end
  end

  def withdraw_proposal_support_on?
    Setting["extended_feature.enable_proposal_support_withdrawal"]
  end

  def filtered_projekt
    projekt_params = params[:projekts] || params[:projekt]

    return nil unless projekt_params.present?
    return nil if projekt_params.split(',').count != 1

    filtered_projekt_id = projekt_params.split(',')[0].to_i
    Projekt.find_by(id: filtered_projekt_id)
  end

  def label_error_class?(field)
    return 'is-invalid-label' if @proposal.errors.any? && @proposal.errors[field].present?
    ""
  end

  def error_text(field)
    return @proposal.errors[:description].join(', ') if @proposal.errors.any? && @proposal.errors[field].present?
    ""
  end
end
