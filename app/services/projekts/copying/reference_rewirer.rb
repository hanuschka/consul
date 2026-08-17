class Projekts::Copying::ReferenceRewirer < ApplicationService
  MAP_EMBED_SELECTOR = ".js-projekt-map-embed[data-map-phase-id]".freeze

  def initialize(source:, copy:, id_map:)
    @source = source
    @copy = copy
    @id_map = id_map
  end

  # Every reference below was copied verbatim and still points into the source
  # projekt. They can only be resolved once the whole graph exists, so they are
  # rewritten in one pass at the end.
  def call
    rewire_poll_questions
    rewire_poll_answers
    rewire_polls
    rewire_navbar_items
    rewire_content_blocks
    rewire_page_content
  end

  private

    attr_reader :source, :copy, :id_map

    def phase_ids
      @phase_ids ||= copy.projekt_phases.ids
    end

    def copy_polls
      @copy_polls ||= Poll.where(projekt_phase_id: phase_ids)
    end

    # The rewiring reads from the SOURCE side: every reference below was left
    # null on the copy, so the copy has nothing to read back. Walking the source
    # and mapping forward also keeps this identical to how every other reference
    # here is resolved.
    def source_questions
      @source_questions ||= Poll::Question
        .where(poll_id: Poll.where(projekt_phase_id: source.projekt_phases.ids).select(:id))
        .includes(:translations)
    end

    # Poll::Question rejects a parent from another poll, so these five columns
    # were left null when the copy was inserted and are written here instead.
    # update_columns skips validation on purpose: the resulting graph is valid,
    # only the intermediate state was not.
    def rewire_poll_questions
      source_questions.each do |source_question|
        references = question_references(source_question)
        next if references.values.all?(&:blank?)

        copy_question_id = mapped(Poll::Question, source_question.id)
        next if copy_question_id.blank?

        Poll::Question.where(id: copy_question_id).update_all(references)
      end
    end

    def question_references(source_question)
      {
        parent_question_id: mapped(Poll::Question, source_question.parent_question_id),
        next_question_id: mapped(Poll::Question, source_question.next_question_id),
        contextualize_by_poll_question_id:
          mapped(Poll::Question, source_question.contextualize_by_poll_question_id),
        contexted_clone_of_poll_question_id:
          mapped(Poll::Question, source_question.contexted_clone_of_poll_question_id),
        context_id: mapped(Poll::Question::Answer, source_question.context_id)
      }
    end

    def rewire_poll_answers
      source_answers = Poll::Question::Answer
        .where(question_id: source_questions.map(&:id))
        .where.not(next_question_id: nil)

      source_answers.each do |source_answer|
        copy_answer_id = mapped(Poll::Question::Answer, source_answer.id)
        next if copy_answer_id.blank?

        Poll::Question::Answer.where(id: copy_answer_id).update_all(
          next_question_id: mapped(Poll::Question, source_answer.next_question_id)
        )
      end
    end

    def rewire_polls
      copy_polls.where.not(budget_id: nil).find_each do |poll|
        poll.update_columns(budget_id: mapped(Budget, poll.budget_id))
      end
    end

    def rewire_navbar_items
      NavbarItem.where(projekt_id: copy.id).find_each do |navbar_item|
        navbar_item.update_columns(
          parent_id: mapped(NavbarItem, navbar_item.parent_id),
          landing_page_id: mapped(SiteCustomization::Page, navbar_item.landing_page_id),
          linked_page_id: mapped(SiteCustomization::Page, navbar_item.linked_page_id)
        )
      end
    end

    def rewire_content_blocks
      SiteCustomization::ContentBlock.where(projekt_id: copy.id).find_each do |content_block|
        rewritten = rewrite_html(content_block.body)
        next if rewritten == content_block.body

        content_block.update_column(:body, rewritten)
      end
    end

    def rewire_page_content
      page = copy.page
      return if page.blank?

      page.translations.each do |translation|
        rewritten = rewrite_html(translation.content)
        next if rewritten == translation.content

        translation.update_column(:content, rewritten)
      end
    end

    # Two things inside stored HTML point at the source: the phase id a map
    # embed renders (HasEmbeddableShortcodes reads data-map-phase-id) and the
    # storage key of every image URL.
    def rewrite_html(html)
      return html if html.blank?

      rewrite_blob_keys(rewrite_map_embeds(html))
    end

    def rewrite_map_embeds(html)
      return html if html.exclude?("js-projekt-map-embed")

      fragment = Nokogiri::HTML::DocumentFragment.parse(html)
      rewritten = false

      fragment.css(MAP_EMBED_SELECTOR).each do |embed|
        copy_phase_id = mapped(ProjektPhase, embed["data-map-phase-id"].to_i)
        next if copy_phase_id.blank?

        embed["data-map-phase-id"] = copy_phase_id.to_s
        rewritten = true
      end

      return html if !rewritten

      fragment.to_html
    end

    def rewrite_blob_keys(html)
      id_map.blob_keys.reduce(html) do |result, (source_key, copy_key)|
        result.gsub(source_key, copy_key)
      end
    end

    def mapped(model_class, source_id)
      id_map.copy_id_for(model_class, source_id)
    end
end
