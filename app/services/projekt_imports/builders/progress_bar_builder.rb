class ProjektImports::Builders::ProgressBarBuilder < ProjektImports::Builders::Base
  def call
    Array(payload).filter_map do |bar|
      next nil if bar["title"].blank?

      phase.progress_bars.create!(
        title: bar["title"],
        kind: bar["kind"].presence || "secondary",
        percentage: bar["percentage"].to_i.clamp(0, 100)
      )
    rescue ActiveRecord::RecordInvalid => e
      raise ProjektImports::Builders::BuilderError, "progress_bar(#{bar['title']}): #{e.message}"
    end
  end
end
