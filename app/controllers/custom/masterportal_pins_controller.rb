class MasterportalPinsController < ApplicationController
  skip_authorization_check only: [:json_data]

  def json_data
    pin = MasterportalPin.find(params[:id])
    associated = pin.associated_record

    render json: {
      resource_type: "masterportal_pin",
      id: pin.id,
      title: pin.title,
      popup_data: pin.popup_data,
      associated_resource_url: pin.associated_resource_url,
      associated_resource_title: associated.try(:title)
    }
  end
end
