class Projekts::Copying::ReferenceRewirer < ApplicationService
  MAP_EMBED_SELECTOR = ".js-projekt-map-embed[data-map-phase-id]".freeze

  # The model each poll-question reference points at, so a source id is only
  # ever looked up against the right half of the IdMap.
  QUESTION_REFERENCE_MODELS = {
    "parent_question_id" => Poll::Question,
    "next_question_id" => Poll::Question,
    "contextualize_by_poll_question_id" => Poll::Question,
    "contexted_clone_of_poll_question_id" => Poll::Question,
    "context_id" => Poll::Question::Answer
  }.freeze

  def initialize(bundle:, copy:, id_map:)
    @bundle = bundle
    @copy = copy
    @id_map = id_map
  end

  # Every reference below named a record of the source and was left null while
  # the graph was rebuilt. They can only be resolved once the whole graph
  # exists, so they are written in one pass at the end.
  def call
    rewire_poll_questions
    rewire_poll_answers
    rewire_polls
    rewire_navbar_items
    rewire_content_blocks
    rewire_page_content
  end

  private

    attr_reader :bundle, :copy, :id_map

    def poll_nodes
      @poll_nodes ||= Array(bundle["phases"])
        .flat_map { |node| Array(node.dig("resources", "polls")) }
    end

    def question_nodes
      @question_nodes ||= poll_nodes.flat_map { |node| Array(node["questions"]) }
    end

    # Poll::Question rejects a parent from another poll, so these five columns
    # were left null when the copy was inserted and are written here instead.
    # update_all skips validation on purpose: the resulting graph is valid, only
    # the intermediate state was not.
    def rewire_poll_questions
      question_nodes.each do |node|
        references = QUESTION_REFERENCE_MODELS.each_with_object({}) do |(name, model), result|
          result[name] = mapped(model, node.dig("references", name))
        end
        next if references.values.all?(&:blank?)

        copy_question_id = mapped(Poll::Question, node["source_id"])
        next if copy_question_id.blank?

        Poll::Question.where(id: copy_question_id).update_all(references)
      end
    end

    def rewire_poll_answers
      question_nodes.flat_map { |node| Array(node["answers"]) }.each do |node|
        next_question_id = mapped(Poll::Question, node.dig("references", "next_question_id"))
        next if next_question_id.blank?

        copy_answer_id = mapped(Poll::Question::Answer, node["source_id"])
        next if copy_answer_id.blank?

        Poll::Question::Answer.where(id: copy_answer_id)
          .update_all(next_question_id: next_question_id)
      end
    end

    # budget_id is excluded when the poll is copied (it is unique per poll), so
    # the copy has nothing to read back -- the link comes off the bundle.
    def rewire_polls
      poll_nodes.each do |node|
        copy_budget_id = mapped(Budget, node.dig("references", "budget_id"))
        next if copy_budget_id.blank?

        copy_poll_id = mapped(Poll, node["source_id"])
        next if copy_poll_id.blank?

        Poll.where(id: copy_poll_id).update_all(budget_id: copy_budget_id)
      end
    end

    # These held real ids, so within one instance an unmapped one keeps pointing
    # where the source pointed -- a navbar item may link to a global page or to
    # another projekt's item, neither of which is part of this copy. An imported
    # bundle carries none of them, so there they arrive null and stay null.
    def rewire_navbar_items
      Array(bundle["navbar_items"]).each do |node|
        copy_navbar_item_id = mapped(NavbarItem, node["source_id"])
        next if copy_navbar_item_id.blank?

        references = node["references"] || {}

        NavbarItem.where(id: copy_navbar_item_id).update_all(
          parent_id: mapped_or_source(NavbarItem, references["parent_id"]),
          landing_page_id:
            mapped_or_source(SiteCustomization::Page, references["landing_page_id"]),
          linked_page_id:
            mapped_or_source(SiteCustomization::Page, references["linked_page_id"])
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
    # storage key of every image URL. An imported bundle duplicates no blob, so
    # its key map is empty and only the embeds are rewritten.
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

    def mapped_or_source(model_class, source_id)
      mapped(model_class, source_id) || source_id
    end
end
