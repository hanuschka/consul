class AiProposalFlow::ProjectSummaryBannerComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def projekt
    @projekt_phase.projekt
  end

  def initial
    projekt.page.title.first.upcase
  end

  def description_snippet
    projekt.page.subtitle.presence || projekt.page.content.to_s.gsub(/<[^>]+>/, "").first(200)
  end

  def projekt_page_url
    helpers.page_path(projekt.page.slug)
  end

  def projekt_image
    projekt.page.image
  end

  private

    attr_reader :projekt_phase
end
