class InternalApiClientsController < ApplicationController
  skip_authorization_check

  def connect
    api_client = InternalApiClient.find_or_initialize_dt
    api_client.update!(domain: Dt.domain)

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
      DtApi::Client.new.clients.connect(
        name: Setting["org_name"],
        platform_url: Setting["url"],
        auth_token: api_client.auth_token,
        **Dt.map_settings,
        consul_env: Rails.env.to_s,
        user_email: current_user.email,
        user_first_name: current_user.first_name,
        user_last_name: current_user.last_name,
        user_id: current_user.id,
        user_role:,
        projekt_manager_projekt_ids:
      )

    if dt_response.present? && dt_response.code != 200
      2.times { puts "" }
      Rails.logger.error("Error connection to server. HTTP code: #{dt_response.code}, message: #{dt_response.message}, response: #{dt_response.response}, url: #{dt_response.request.uri}")
      2.times { puts "" }
    end

    redirect_url = dt_response["redirect_url"]
    redirect_type = dt_response["redirect_type"]

    if dt_response.code === 200
      flash[:notice] = I18n.t("internal_api_clients.connect.success")
      redirect_back(fallback_location: admin_connection_path)
    else
      if dt_response.code == 200
        flash[:error] =
          "Error connecting to DT. HTTP code: #{dt_response.code}, http message: #{dt_response.message}"
      else
        flash[:error] =
          "Error connecting to DT. HTTP code: #{dt_response.code}, error: #{dt_response["error"]}"
      end
      redirect_back(fallback_location: root_path)
    end
  end
end
