# frozen_string_literal: true

class BudgetInvestmentSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[title description].freeze

  PRELOADS = [
    :translations,
    :map_location,
    :masterportal_pin,
    :tags,
    { heading: :translations },
    { group: :translations },
    { sentiment: :translations },
    { administrator: :user },
    { projekt_labels: :translations },
    { image: { attachment_attachment: :blob } },
    { documents: { attachment_attachment: :blob } },
    { author: :organization },
    {
      budget: [
        :translations,
        :report,
        { image: { attachment_attachment: :blob } },
        { projekt_phase: [:settings, :translations, { projekt: { page: :translations } }] },
        { group: [:translations, { heading: :translations }] }
      ]
    }
  ].freeze

  attr_reader :budget_investment

  def initialize(
    budget_investment,
    client: nil,
    similar_contributions_count: nil,
    hide_unpublished_selection: false,
    counts: nil
  )
    @budget_investment = budget_investment
    @client = client
    @similar_contributions_count = similar_contributions_count
    @hide_unpublished_selection = hide_unpublished_selection
    @counts = counts
  end

  def serialize
    investment_data = budget_investment.as_json(
      only: [
        :id,
        :heading_id,
        :group_id,
        :budget_id,
        :cached_votes_up,
        :created_at,
        :updated_at,
        :video_url,
        :on_behalf_of,
        :feasibility,
        :valuation_finished,
        :selected,
        :physical_votes,
        :sentiment_id
      ]
    )

    investment_data.merge!(
      title: budget_investment.title,
      description: budget_investment.description,
      translations: serialize_translations(budget_investment, TRANSLATED_ATTRIBUTES),
      comments_count: counts[:comments_count],
      total_votes: counts[:votes_count] + budget_investment.physical_votes.to_i,
      similar_contributions_count: similar_contributions_count,
      **serialize_external_reference(budget_investment),
      map_location: serialize_map_location(budget_investment.map_location),
      projekt_labels: serialize_projekt_labels,
      sentiment: serialize_sentiment
    )

    if @hide_unpublished_selection
      investment_data["selected"] = budget_investment.publicly_selected?
    end

    merge_admin_fields(investment_data)
    merge_gated_fields(investment_data)

    if budget_investment.author.present?
      investment_data[:author] = serialize_on_behalf_of_author(budget_investment)
    end

    if budget_investment.heading.present?
      investment_data[:heading] = {
        id: budget_investment.heading.id,
        name: budget_investment.heading.name
      }
    end

    if budget_investment.group.present?
      investment_data[:group] = {
        id: budget_investment.group.id,
        name: budget_investment.group.name
      }
    end

    if budget_investment.budget.present?
      merge_budget(investment_data, serialize_budget(budget_investment.budget))
    end

    if budget_investment.image.present?
      serialized_image = ImageSerializer.new(budget_investment.image, include_variants: false).serialize
      investment_data[:image] = serialized_image if serialized_image.present?
    end

    if budget_investment.documents.any?
      investment_data[:documents] = DocumentSerializer.serialize_collection(budget_investment.documents)
    end

    if budget_investment.tags.any?
      investment_data[:tags] = budget_investment.tags.map(&:name)
    end

    investment_data[:feasible] = budget_investment.feasible?
    investment_data[:feasible_with_changes] = budget_investment.feasible_with_changes?
    investment_data[:unfeasible] = budget_investment.unfeasible?
    investment_data[:undecided] = budget_investment.undecided?

    investment_data
  end

  def self.serialize_collection(budget_investments, client: nil, hide_unpublished_selection: false)
    similar_counts = SimilarContributions::StoredCounts.call(budget_investments)
    counts_by_id = counts_for(budget_investments.map(&:id))

    budget_investments.map do |budget_investment|
      new(
        budget_investment,
        client: client,
        similar_contributions_count: similar_counts.fetch(budget_investment.id, 0),
        hide_unpublished_selection: hide_unpublished_selection,
        counts: counts_by_id[budget_investment.id]
      ).serialize
    end
  end

  # One grouped query per count for the whole page instead of one per
  # investment and count.
  def self.counts_for(investment_ids)
    comments_counts =
      Comment
        .where(commentable_type: "Budget::Investment", commentable_id: investment_ids)
        .group(:commentable_id)
        .count
    votes_counts =
      Vote
        .where(votable_type: "Budget::Investment", votable_id: investment_ids, conditional: false)
        .group(:votable_id)
        .sum(:vote_weight)
    ballot_votes_counts =
      Budget::Ballot::Line
        .joins(:ballot)
        .where(investment_id: investment_ids, budget_ballots: { conditional: false })
        .group(:investment_id)
        .sum(:line_weight)

    investment_ids.index_with do |investment_id|
      {
        comments_count: comments_counts.fetch(investment_id, 0),
        votes_count: votes_counts.fetch(investment_id, 0),
        ballot_votes_count: ballot_votes_counts.fetch(investment_id, 0)
      }
    end
  end

  private

    def counts
      @counts ||= self.class.counts_for([budget_investment.id]).fetch(budget_investment.id)
    end

    def similar_contributions_count
      @similar_contributions_count ||=
        SimilarContributions::StoredCounts
          .call([budget_investment])
          .fetch(budget_investment.id, 0)
    end

    def merge_admin_fields(investment_data)
      return if !admin_client?

      investment_data.merge!(
        author_id: budget_investment.author_id,
        administrator_id: budget_investment.administrator_id,
        confidence_score: budget_investment.confidence_score,
        visible_to_valuators: budget_investment.visible_to_valuators,
        code: budget_investment.code,
        price_first_year: budget_investment.price_first_year,
        duration: budget_investment.duration,
        external_url: budget_investment.external_url,
        location: budget_investment.location
      )

      if budget_investment.administrator.present?
        investment_data[:administrator] = {
          id: budget_investment.administrator.id,
          name: budget_investment.administrator.user&.name
        }
      end
    end

    # Read-only clients get each value only where the public investment page
    # shows it.
    def merge_gated_fields(investment_data)
      budget = budget_investment.budget

      if admin_client? || budget_investment.should_show_price?
        investment_data[:price] = budget_investment.price
        investment_data[:price_explanation] = budget_investment.price_explanation
      end

      if admin_client? || (budget_investment.unfeasible? && budget_investment.valuation_finished?)
        investment_data[:unfeasibility_explanation] = budget_investment.unfeasibility_explanation
      end

      if valuator_explanation_visible? && budget_investment.valuator_explanation.present?
        investment_data[:valuator_explanation] = budget_investment.valuator_explanation
      end

      if admin_client? || budget_investment.should_show_ballots_count?
        investment_data[:ballot_lines_count] = budget_investment.ballot_lines_count
        investment_data[:total_ballot_votes] = counts[:ballot_votes_count]
      end

      if admin_client? || results_public?(budget)
        investment_data[:winner] = budget_investment.winner
        investment_data[:incompatible] = budget_investment.incompatible
        investment_data[:final_winner] = budget_investment.final_winner?
      end

      if admin_client? || budget&.valuating_or_later?
        investment_data[:preselected] = budget_investment.preselected
      end

      if admin_client? || phase_feature?("form.show_implementation_option_fields")
        investment_data[:implementation_performer] = budget_investment.implementation_performer
        investment_data[:implementation_contribution] = budget_investment.implementation_contribution
      end

      if admin_client? || phase_feature?("form.show_user_cost_estimate")
        investment_data[:user_cost_estimate] = budget_investment.user_cost_estimate
      end
    end

    def merge_budget(investment_data, budget_data)
      investment_data[:budget] = budget_data

      if budget_data[:projekt_phase].present?
        investment_data[:projekt_phase] = budget_data[:projekt_phase]
      end

      if budget_data[:projekt].present?
        investment_data[:projekt] = budget_data[:projekt]
      end
    end

    def valuator_explanation_visible?
      admin_client? ||
        budget_investment.should_show_price_explanation? ||
        budget_investment.should_show_unfeasibility_explanation? ||
        budget_investment.should_show_feasibility_explanation? ||
        budget_investment.should_show_changes_explanation?
    end

    def results_public?(budget)
      budget.present? && budget.finished? && budget.results_enabled?
    end

    def phase_feature?(key)
      projekt_phase = budget_investment.budget&.projekt_phase

      projekt_phase.present? && projekt_phase.feature?(key)
    end

    def serialize_projekt_labels
      budget_investment.projekt_labels.map do |projekt_label|
        {
          id: projekt_label.id,
          name: projekt_label.name,
          color: projekt_label.color,
          icon: projekt_label.icon
        }
      end
    end

    def serialize_sentiment
      sentiment = budget_investment.sentiment
      return nil if sentiment.blank?

      { id: sentiment.id, name: sentiment.name, color: sentiment.color }
    end

    def serialize_budget(budget)
      budget_data = {
        id: budget.id,
        name: budget.name,
        phase: budget.phase,
        currency_symbol: budget.currency_symbol,
        voting_style: budget.voting_style,
        published: budget.published,
        slug: budget.slug,
        hide_money: budget.hide_money,
        max_number_of_winners: budget.max_number_of_winners,
        show_percentage_values_only: budget.show_percentage_values_only,
        show_results_after_first_vote: budget.show_results_after_first_vote,
        max_preselected: budget.max_preselected,
        created_at: budget.created_at,
        updated_at: budget.updated_at
      }

      if budget.projekt_phase.present?
        budget_data[:projekt_phase] = {
          id: budget.projekt_phase.id,
          title: budget.projekt_phase.phase_tab_name,
          type: budget.projekt_phase.type,
          projekt_id: budget.projekt_phase.projekt_id
        }

        if budget.projekt_phase.projekt.present?
          projekt = budget.projekt_phase.projekt
          budget_data[:projekt] = {
            id: projekt.id,
            title: projekt.page&.title || projekt.name
          }
        end
      end

      if budget.image.present?
        serialized_image = ImageSerializer.new(budget.image, include_variants: false).serialize
        budget_data[:image] = serialized_image if serialized_image.present?
      end

      if budget.group.present?
        budget_data[:group] = serialize_budget_group(budget.group)
      end

      budget_data
    end

    def serialize_budget_group(group)
      group_data = {
        id: group.id,
        name: group.name,
        slug: group.slug
      }

      if group.heading.present?
        heading = group.heading
        group_data[:heading] = {
          id: heading.id,
          name: heading.name,
          slug: heading.slug,
          price: heading.price
        }
      end

      group_data
    end
end
