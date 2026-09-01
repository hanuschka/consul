class Projekts::ImportContentFromDocumentJob < ApplicationJob
  queue_as :default

  def perform(projekt_id)
    projekt = Projekt.find(projekt_id)
    ProjektContentBlocks::AiGenerateWithFile.call(projekt: projekt)
  rescue => e
    projekt.update_columns(
      import_file_status: "failed",
      import_file_data: { error: { message: "Unerwarteter Fehler beim Import: #{e.message}" } }
    )
    raise e
  end
end
