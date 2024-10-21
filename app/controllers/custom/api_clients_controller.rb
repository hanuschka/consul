class ApiClientsController < ApplicationController
  skip_authorization_check

  def connect
    api_client = ApiClient.find_or_create_by!(
      name: "DT",
      domain: Rails.application.secrets.dt[:domain]
    )

    user_role =
      if current_user.administrator?
        :admin
      elsif current_user.projekt_manager?
        :projekt_manager
      end

    projekt_manager_projekt_ids =
      if current_user.projekt_manager?
        current_user
          .projekt_manager
          .projekt_manager_assignments
          .where("permissions  @> ?", "{manage}")
          .pluck(:projekt_id)
      end

    dt_response =
      DtApi.connect(
        name: Setting["org_name"],
        auth_token: api_client.auth_token,
        latitude: Setting["map.latitude"],
        longitude: Setting["map.longitude"],
        zoom: Setting["map.zoom"],
        user_email: current_user.email,
        user_first_name: current_user.first_name,
        user_last_name: current_user.last_name,
        user_id: current_user.id,
        role: user_role,
        projekt_manager_projekt_ids: projekt_manager_projekt_ids
      )

    redirect_url = dt_response["redirect_url"]

    if redirect_url.present?
      redirect_to redirect_url
    else
      flash[:error] = "Error connecting to DT"
      redirect_back(fallback_location: root_path)
    end
  end
end
