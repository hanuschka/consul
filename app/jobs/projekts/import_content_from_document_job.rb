class Projekts::ImportContentFromDocumentJob < ApplicationJob
  queue_as :default
  self.max_run_time = Ai::Settings::JOB_MAX_RUN_TIME

  def perform(projekt_id)
    projekt = Projekt.find(projekt_id)
    ProjektContentBlocks::AiGenerateWithFile.call(projekt: projekt)
  rescue => e
    projekt.update_columns(
      import_file_status: "failed",
      import_file_data: {
        error: {
          message: I18n.t("custom.projekt_content_blocks.ai_generate_with_file.unexpected_error")
        }
      }
    )
    raise e
  end
end
