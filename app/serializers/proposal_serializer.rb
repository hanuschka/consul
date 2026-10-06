class ProposalSerializer < BaseSerializer
  attr_reader :proposal

  def initialize(proposal, similar_contributions_count: nil)
    @proposal = proposal
    @similar_contributions_count = similar_contributions_count
  end

  def serialize
    proposal_data = proposal.as_json(
      only: [
        :id,
        :author_id,
        :cached_votes_up,
        :cached_votes_down,
        :comments_count,
        :hot_score,
        :confidence_score,
        :created_at,
        :updated_at,
        :responsible_name,
        :video_url,
        :geozone_id,
        :retired_at,
        :retired_reason,
        :published_at,
        :selected,
        :sentiment_id,
        :official_answer,
        :officing_bulk_votes
      ]
    )

    proposal_data[:similar_contributions_count] = similar_contributions_count

    proposal_data.merge!(
      title: proposal.title,
      description: proposal.description,
      summary: proposal.summary,
      retired_explanation: proposal.retired_explanation
    )

    if proposal.author.present?
      proposal_data[:author] = {
        id: proposal.author.id,
        username: proposal.author.username,
        public_name: proposal.author.public_name
      }
    end

    # Add geozone
    if proposal.geozone.present?
      proposal_data[:geozone] = {
        id: proposal.geozone.id,
        name: proposal.geozone.name
      }
    end

    # Add projekt phase info
    if proposal.projekt_phase.present?
      proposal_data[:projekt_phase] = {
        id: proposal.projekt_phase.id,
        title: proposal.projekt_phase.phase_tab_name,
        type: proposal.projekt_phase.type,
        projekt_id: proposal.projekt_phase.projekt_id
      }

      # Add projekt info
      if proposal.projekt_phase.projekt.present?
        projekt = proposal.projekt_phase.projekt
        proposal_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    # Add tags
    proposal_data[:tags] = proposal.tags.pluck(:name) if proposal.tags.any?

    # Add projekt labels
    if proposal.respond_to?(:projekt_labels) && proposal.projekt_labels.any?
      proposal_data[:projekt_labels] = proposal.projekt_labels.as_json(
        only: [:id, :name, :color]
      )
    end

    # Add sentiment
    if proposal.respond_to?(:sentiment) && proposal.sentiment.present?
      proposal_data[:sentiment] = {
        id: proposal.sentiment.id,
        name: proposal.sentiment.name,
        color: proposal.sentiment.color
      }
    end

    if proposal.map_location.present?
      proposal_data[:map_location] = {
        latitude: proposal.map_location.latitude,
        longitude: proposal.map_location.longitude,
        zoom: proposal.map_location.zoom
      }
    end

    if proposal.respond_to?(:image) && proposal.image.present?
      serialized_image = ImageSerializer.new(proposal.image, include_variants: true).serialize
      proposal_data[:image] = serialized_image if serialized_image.present?
    end

    if proposal.respond_to?(:documents) && proposal.documents.any?
      proposal_data[:documents] = proposal.documents.map do |doc|
        {
          id: doc.id,
          title: doc.title,
          attachment_file_name: doc.attachment_file_name,
          attachment_file_size: doc.attachment_file_size
        }
      end
    end

    proposal_data
  end

  def self.serialize_collection(proposals)
    counts = SimilarContributions::StoredCounts.call(proposals)

    proposals.map do |proposal|
      new(proposal, similar_contributions_count: counts.fetch(proposal.id, 0)).serialize
    end
  end

  private

    def similar_contributions_count
      @similar_contributions_count ||=
        SimilarContributions::StoredCounts.call([proposal]).fetch(proposal.id, 0)
    end
end

