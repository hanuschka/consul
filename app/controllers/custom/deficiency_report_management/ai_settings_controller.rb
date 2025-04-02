class DeficiencyReportManagement::AiSettingsController < DeficiencyReportManagement::BaseController
  def show
    @assistant_codename = "deficiency_report_voice_assistant"

    dt_api = DtApi::Client.new

    ai_assistant_config_response =
      dt_api
        .ai_assistant_configs
        .get(
          codename: @assistant_codename
        )

    @ai_assistant_config =
      ai_assistant_config_response
        .fetch("client_ai_assistant_config")
  end

  def update
    dt_response =
      DtApi::Client.new
        .ai_assistant_configs
        .update(
          codename: params[:assistant_codename],
          params: {
            questions: params[:questions],
            criteria: params[:criteria],
            parting_words: params[:parting_words]
          }
        )

    if dt_response["status"] == "error"
      flash[:error] = "Error updating config. #{dt_response["error_message"]}"
    end

    redirect_to action: :show
  end
end
