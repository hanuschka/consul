class ProjektImports::Builders::MilestoneBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |ms|
      next nil if ms["title"].blank?

      phase.milestones.create!(
        title: ms["title"],
        description: ms["description"],
        publication_date: ms["publication_date"]
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "milestone(#{ms['title']}): #{e.message}"
    end
  end
end
