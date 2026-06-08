class ProjektImports::Builders::LivestreamBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |ls|
      next nil if ls["url"].blank?

      phase.projekt_livestreams.create!(
        url: ls["url"],
        title: ls["title"],
        description: ls["description"],
        starts_at: ls["starts_at"]
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "livestream(#{ls['url']}): #{e.message}"
    end
  end
end
