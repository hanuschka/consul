class MapData::ProposalPhase < ApplicationService
  def initialize(projekt_phase:, search: nil, projekt_label_ids: nil,
                 sentiment_id: nil, my_posts_user_id: nil)
    @projekt_phase = projekt_phase
    @search = search
    @projekt_label_ids = projekt_label_ids
    @sentiment_id = sentiment_id
    @my_posts_user_id = my_posts_user_id
  end

  def call
    proposal_ids = filtered_proposals.ids
    features = MapLocation.where(mappable_type: "Proposal", mappable_id: proposal_ids)
                          .includes(mappable: [:projekt_labels, :projekt_phase,
                                               :sentiment, :masterportal_pin])
                          .map(&:features_json_data)
    features += MasterportalPin.standalone_features_for_phase(@projekt_phase)

    { type: "FeatureCollection", features: features }
  end

  private

    def filtered_proposals
      resources = @projekt_phase.proposals
                                .base_selection
                                .with_min_supports(min_supports)

      if @search.present?
        resources = resources.search(@search)
      else
        resources = apply_label_filter(resources)
        resources = apply_sentiment_filter(resources)
        resources = apply_my_posts_filter(resources)
      end

      resources
    end

    def min_supports
      @projekt_phase.settings
                    .find_by(key: "option.resource.minimum_supports_to_show")
                    &.value.to_i
    end

    def apply_label_filter(resources)
      return resources if @projekt_label_ids.blank?

      resources
        .joins(:projekt_labels)
        .where(projekt_labels: { id: @projekt_label_ids })
    end

    def apply_sentiment_filter(resources)
      return resources if @sentiment_id.blank?

      resources.where(sentiment_id: @sentiment_id)
    end

    def apply_my_posts_filter(resources)
      return resources if @my_posts_user_id.blank?

      resources.by_author(@my_posts_user_id)
    end
end
