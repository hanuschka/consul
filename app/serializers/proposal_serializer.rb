class ProposalSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[title description summary retired_explanation].freeze

  attr_reader :proposal

  def initialize(proposal, client: nil, similar_contributions_count: nil)
    @proposal = proposal
    @client = client
    @similar_contributions_count = similar_contributions_count
  end

  def serialize
    proposal_data = proposal.as_json(
      only: [
        :id,
        :cached_votes_up,
        :cached_votes_down,
        :comments_count,
        :hot_score,
        :confidence_score,
        :created_at,
        :updated_at,
        :video_url,
        :geozone_id,
        :retired_at,
        :retired_reason,
        :published_at,
        :selected,
        :sentiment_id,
        :official_answer,
        :officing_bulk_votes,
        :on_behalf_of,
        :projekt_phase_id
      ]
    )

    proposal_data[:similar_contributions_count] = similar_contributions_count

    if admin_client?
      proposal_data.merge!(
        author_id: proposal.author_id,
        responsible_name: proposal.responsible_name,
        admin_accepted: proposal.admin_accepted
      )
    end

    proposal_data.merge!(
      title: proposal.title,
      description: proposal.description,
      summary: proposal.summary,
      retired_explanation: proposal.retired_explanation,
      translations: serialize_translations(proposal, TRANSLATED_ATTRIBUTES),
      **serialize_external_reference(proposal),
      tags: proposal.tags.map(&:name),
      projekt_labels: serialize_projekt_labels,
      map_location: serialize_map_location(proposal.map_location)
    )

    if proposal.author.present?
      proposal_data[:author] = serialize_on_behalf_of_author(proposal)
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

    # Add sentiment
    if proposal.sentiment.present?
      proposal_data[:sentiment] = {
        id: proposal.sentiment.id,
        name: proposal.sentiment.name,
        color: proposal.sentiment.color
      }
    end

    if proposal.image.present?
      serialized_image = ImageSerializer.new(proposal.image, include_variants: true).serialize
      proposal_data[:image] = serialized_image if serialized_image.present?
    end

    if proposal.documents.any?
      proposal_data[:documents] = DocumentSerializer.serialize_collection(proposal.documents)
    end

    proposal_data
  end

  def self.serialize_collection(proposals, client: nil)
    counts = SimilarContributions::StoredCounts.call(proposals)

    proposals.map do |proposal|
      new(
        proposal,
        client: client,
        similar_contributions_count: counts.fetch(proposal.id, 0)
      ).serialize
    end
  end

  private

    def similar_contributions_count
      @similar_contributions_count ||=
        SimilarContributions::StoredCounts.call([proposal]).fetch(proposal.id, 0)
    end

    def serialize_projekt_labels
      proposal.projekt_labels.map do |projekt_label|
        {
          id: projekt_label.id,
          name: projekt_label.name,
          color: projekt_label.color,
          icon: projekt_label.icon
        }
      end
    end
end
