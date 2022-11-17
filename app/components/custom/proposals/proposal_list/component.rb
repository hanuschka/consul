class Proposals::ProposalList::Component < ApplicationComponent
  renders_one :body

  def initialize(proposals:, title:, wide: false)
    @proposals = proposals
    @title = title
    @wide = wide
  end

  def class_names
    if @wide
      "-wide"
    end
  end
end
