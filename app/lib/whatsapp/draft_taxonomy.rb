module Whatsapp::DraftTaxonomy
  # The two choices a phase can demand of a draft beyond its text — a category
  # and a sentiment — behind one duck interface, so the pipeline asks "which
  # requirement is unmet" instead of spelling both out at every step.

  module_function

  def category(projekt_phase)
    Whatsapp::DraftTaxonomy::Category.new(projekt_phase: projekt_phase)
  end

  def sentiment(projekt_phase)
    Whatsapp::DraftTaxonomy::Sentiment.new(projekt_phase: projekt_phase)
  end

  # Order is the ask order: the category question comes first when both are
  # open, matching the C15 catalog sequence.
  def requirements(projekt_phase)
    [category(projekt_phase), sentiment(projekt_phase)]
  end
end
