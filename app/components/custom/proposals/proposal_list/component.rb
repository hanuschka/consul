class Proposals::ProposalList::Component < ApplicationComponent
  renders_one :body

  def initialize(proposal:, title:, wide: false)
    @proposal = proposal
    @title = title
    @wide = wide
  end

  def class_names
    if @wide
      "-wide"
    end
  end
end
