class FileManager::BaseController < Adm::BaseController
  private

    def current_projekt
      @current_projekt ||= Projekt.find_by(id: params[:projekt_id])
    end
end
