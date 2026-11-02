load Rails.root.join("app", "components", "moderation", "shared", "index_component.rb")

class Moderation::Shared::IndexComponent < ApplicationComponent
  private

    def form_path
      url_for(
        request.query_parameters.merge(
          controller: "#{namespace}/#{section_name}",
          action: "moderate",
          only_path: true
        )
      )
    end

    def namespace
      params[:controller].split("/").first
    end
end
