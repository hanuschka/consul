class SimilarContributions::ProgressComponent < ApplicationComponent
  include SimilarContributionsCheckState

  attr_reader :resource

  def initialize(resource)
    @resource = resource
  end
end
