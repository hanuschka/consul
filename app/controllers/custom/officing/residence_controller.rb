require_dependency Rails.root.join("app", "controllers", "officing", "residence_controller").to_s
class Officing::ResidenceController < Officing::BaseController

  def create
    @residence = Officing::Residence.new(residence_params.merge(officer: current_user.poll_officer))

    @residence.errors.add :first_name, :blank if residence_params[:first_name].blank?
    @residence.errors.add :last_name, :blank if residence_params[:last_name].blank?
    @residence.errors.add :date_of_birth, :blank if residence_params['date_of_birth(1i)'].blank? || residence_params['date_of_birth(2i)'].blank? || residence_params['date_of_birth(3i)'].blank?
    @residence.errors.add :postal_code, :blank if residence_params[:postal_code].blank?
    @residence.errors.add :postal_code, :format unless residence_params[:postal_code] =~ /\A\d{5}\z/
    @residence.errors.add :document_type, :blank if residence_params[:document_type].blank?
    @residence.errors.add :document_number, :blank if params[:residence][:document_number].blank?
    @residence.errors.add :document_number, :length unless params[:residence][:document_number].length == 4

    if @residence.errors.any?
      render :new and return
    end

    verification_request = Verifications::CreateXML.create_verification_request_in_booth(@residence)
    sleep 7
    responce = Verifications::CheckXML.check_verification_request_in_booth(verification_request)

    if responce[:result] == 'no_response'
      flash.alert = t('cli.officing.residence.notifications.no_responce')
      render :new
    elsif responce[:result] == 'false'
      flash.alert = t('cli.officing.residence.notifications.verification_false')
      responce[:errors].each { |error_field| @residence.errors.add(error_field) }
      render :new
    elsif responce[:result] == 'true'
     if @residence.save
      redirect_to new_officing_voter_path(id: @residence.user.id), notice: t("officing.residence.flash.create")
     else
      flash.alert = t('cli.officing.residence.notifications.verification_false')
      render :new
     end
    end
  end

  private

    def residence_params
      params.require(:residence).permit(:document_type, :year_of_birth,
                                        :date_of_birth, :postal_code, :first_name, :last_name)
    end
end
