class AiProposalFlow::ProjectSummaryBannerComponent < ApplicationComponent
  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def projekt
    @projekt_phase.projekt
  end

  def description_snippet
    text = projekt.page.subtitle.presence || helpers.strip_tags(projekt.page.content.to_s).first(200)
    helpers.sanitize(text)
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
