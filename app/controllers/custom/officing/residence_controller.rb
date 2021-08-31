require_dependency Rails.root.join("app", "controllers", "officing", "residence_controller").to_s
class Officing::ResidenceController < Officing::BaseController

  def create
    @residence = Officing::Residence.new(residence_params.merge(officer: current_user.poll_officer))
    verification_request = Verifications::CreateXML.create_verification_request_in_booth(@residence)
    sleep 7
    responce = Verifications::CheckXML.check_verification_request_in_booth(verification_request)

    if responce[:result] == 'no_response'
      flash.alert = "Please try again later"
      render :new
    elsif responce[:result] == 'false'
      flash.alert = "Please correct errors"
      responce[:errors].each { |error_field| @residence.errors.add(error_field) }
      render :new
    elsif responce[:result] == 'true'
     if @residence.save
      redirect_to new_officing_voter_path(id: @residence.user.id), notice: t("officing.residence.flash.create")
     else
      flash.alert = "Couldn't save"
      render :new
     end
    end
  end

  private

    def residence_params
      params.require(:residence).permit(:document_number, :document_type, :year_of_birth,
                                        :date_of_birth, :postal_code, :first_name, :last_name)
    end
end
