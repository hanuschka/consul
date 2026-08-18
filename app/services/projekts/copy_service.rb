class Projekts::CopyService < ApplicationService
  def initialize(source:, copy:)
    @source = source
    @copy = copy
    @id_map = Projekts::Copying::IdMap.new
    @record_copier = Projekts::Copying::RecordCopier.new(id_map: @id_map)
  end

  def call
    ActiveRecord::Base.transaction do
      copy_projekt
      copy_phases
      copy_content_blocks
      rewire_references
    end

    ServiceResult.success(projekt: copy)
  rescue StandardError => e
    Rails.logger.error(
      "[Projekts::CopyService] failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    )

    if defined?(Sentry)
      Sentry.capture_exception(e, extra: { source_projekt_id: source.id, copy_projekt_id: copy.id })
    end

    ServiceResult.failure(error: e.message)
  end

  private

    attr_reader :source, :copy, :id_map, :record_copier

    def copy_projekt
      Projekts::Copying::ProjektCopier.call(
        source: source, copy: copy,
        record_copier: record_copier
      )
    end

    def copy_phases
      source.projekt_phases.order(:given_order, :id).each do |source_phase|
        Projekts::Copying::PhaseCopier.call(
          source_phase: source_phase, copy_projekt: copy,
          record_copier: record_copier
        )
      end
    end

    def copy_content_blocks
      Projekts::Copying::ContentBlockCopier.call(
        source: source, copy: copy,
        record_copier: record_copier
      )
    end

    def rewire_references
      Projekts::Copying::ReferenceRewirer.call(source: source, copy: copy.reload, id_map: id_map)
    end
end
