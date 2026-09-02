class ProjektImports::Builders::MilestoneBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |milestone|
      next nil if milestone["title"].blank?

      phase.milestones.create!(
        title: milestone["title"],
        description: milestone["description"].presence || milestone["title"],
        publication_date: publication_date_for(milestone)
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError,
        "milestone(#{milestone["title"]}): #{e.message}"
    end
  end

  private

  # Milestone validates both description and publication_date as present, while
  # the import schema lets the model return either as null. Falling back keeps a
  # dateless milestone importable instead of failing the whole phase.
  def publication_date_for(milestone)
    milestone["publication_date"].presence || phase.start_date || Date.current
  end
end
