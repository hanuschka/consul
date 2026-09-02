class Projekts::Copying::PollCopier < ApplicationService
  # projekt_id and projekt_phase_id are re-pointed at the copy, and budget_id is
  # unique per poll -- it travels as a reference and the rewiring pass resolves
  # it. slug and the ai_stats columns never left the serializer.
  EXCLUDED_POLL_COLUMNS = %w[projekt_id projekt_phase_id].freeze

  # Poll::Question#validate_parent_question_id rejects a parent from another
  # poll, so these cannot be carried over and fixed later -- they are left null
  # and resolved by the rewiring pass.
  EXCLUDED_QUESTION_COLUMNS = %w[poll_id].freeze

  EXCLUDED_ANSWER_COLUMNS = %w[question_id].freeze

  def initialize(nodes:, copy_phase:, record_copier:)
    @nodes = Array(nodes)
    @copy_phase = copy_phase
    @record_copier = record_copier
  end

  # ProjektPhase::VotingPhase#create_poll already gave the copy an empty poll,
  # so the first source poll takes it over instead of landing beside it.
  def call
    return if nodes.empty?

    scaffolded_polls = Poll.where(projekt_phase_id: copy_phase.id).order(:id).to_a

    nodes.each_with_index do |node, index|
      copy_poll(node, scaffolded_polls[index])
    end
  end

  private

    attr_reader :nodes, :copy_phase, :record_copier

    def copy_poll(node, scaffolded_poll)
      copy = record_copier.overwrite_or_copy(
        node, scaffolded_poll,
        attributes: {
          projekt_phase_id: copy_phase.id,
          projekt_id: copy_phase.projekt_id,
          slug: nil
        },
        except: EXCLUDED_POLL_COLUMNS
      )

      replace_scaffolded_image(node, copy)
      record_copier.copy_attachments(node, copy)
      copy_sdg_relations(node, copy)

      Array(node["questions"]).each { |question_node| copy_question(question_node, copy) }
    end

    # VotingPhase#create_poll seeds the scaffolded poll with a copy of the
    # projekt image; the source poll's own image replaces it, since Poll has
    # only one. An imported poll brings none, so the scaffold's is left alone.
    def replace_scaffolded_image(node, copy)
      return if Array(node["images"]).empty?
      return if copy.image.blank?

      copy.image.destroy!
      copy.reload
    end

    def copy_sdg_relations(node, copy)
      related_sdgs = Projekts::Copying::Serializing::SdgCodeSerializer
        .resolve(node["sdg_relations"])

      related_sdgs.each do |related_sdg|
        copy.sdg_relations.find_or_create_by!(related_sdg: related_sdg)
      end
    end

    def copy_question(node, copy_poll)
      copy = record_copier.build(
        node,
        attributes: { poll_id: copy_poll.id },
        except: EXCLUDED_QUESTION_COLUMNS
      )
      copy.votation_type = built_votation_type(node)
      record_copier.persist(node, copy)

      record_copier.copy_attachments(node, copy)

      Array(node["answers"]).each { |answer_node| copy_answer(answer_node, copy) }
    end

    # Poll::Question validates votation_type presence, so it has to be in place
    # before the copy is saved.
    def built_votation_type(node)
      votation_type_node = node["votation_type"]
      return nil if votation_type_node.blank?

      record_copier.build(
        votation_type_node,
        except: %w[questionable_type questionable_id]
      )
    end

    def copy_answer(node, copy_question)
      copy = record_copier.copy_record(
        node,
        attributes: { question_id: copy_question.id },
        except: EXCLUDED_ANSWER_COLUMNS
      )

      record_copier.copy_attachments(node, copy)
      record_copier.copy_all(node["videos"], attributes: { answer_id: copy.id })
    end
end
