# The one traversal of a projekt. A local copy and a cross-instance import both
# run it over a bundle of the same shape -- what tells them apart is only what
# their bundle contains, never the order or the rules below.
class Projekts::Copying::CopyRunner < ApplicationService
  def initialize(bundle:, copy:, record_copier:, id_map:)
    @bundle = bundle
    @copy = copy
    @record_copier = record_copier
    @id_map = id_map
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
      "[Projekts::Copying::CopyRunner] failed: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    )

    if defined?(Sentry)
      Sentry.capture_exception(e, extra: { copy_projekt_id: copy.id })
    end

    ServiceResult.failure(error: e.message)
  end

  private

    attr_reader :bundle, :copy, :record_copier, :id_map

    def copy_projekt
      Projekts::Copying::ProjektCopier.call(
        bundle: bundle, copy: copy,
        record_copier: record_copier
      )
    end

    def copy_phases
      Array(bundle["phases"]).each do |node|
        Projekts::Copying::PhaseCopier.call(
          node: node, copy_projekt: copy,
          record_copier: record_copier
        )
      end
    end

    def copy_content_blocks
      Projekts::Copying::ContentBlockCopier.call(
        bundle: bundle, copy: copy,
        record_copier: record_copier
      )
    end

    def rewire_references
      Projekts::Copying::ReferenceRewirer.call(
        bundle: bundle, copy: copy.reload, id_map: id_map
      )
    end
end
