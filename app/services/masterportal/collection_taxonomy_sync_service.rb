class Masterportal::CollectionTaxonomySyncService < ApplicationService
  DEFAULT_ICON = "tag".freeze
  DEFAULT_COLOR = "#1b5fd6".freeze

  LABEL_PHASE_TYPES = %w[
    ProjektPhase::ProposalPhase
    ProjektPhase::BudgetPhase
  ].freeze

  CATEGORY_PHASE_TYPES = %w[
    ProjektPhase::PointOfInterestPhase
  ].freeze

  def self.out_of_sync?(projekt_phase:)
    return false if !projekt_phase.use_masterportal_collections_as_labels?

    scope = backed_scope_for(projekt_phase)
    return false if scope.nil?

    scope.count < projekt_phase.masterportal_collections.count
  end

  def self.backed_scope_for(projekt_phase)
    taxonomy_association_for(projekt_phase)&.collection_backed
  end

  def self.taxonomy_association_for(projekt_phase)
    if LABEL_PHASE_TYPES.include?(projekt_phase.type)
      projekt_phase.projekt_labels
    elsif CATEGORY_PHASE_TYPES.include?(projekt_phase.type)
      projekt_phase.projekt_point_of_interest_categories
    end
  end

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
  end

  def call
    return if !@projekt_phase.use_masterportal_collections_as_labels?

    taxonomy = self.class.taxonomy_association_for(@projekt_phase)
    return if taxonomy.nil?

    collections.each { |collection| upsert(taxonomy, collection) }
    remove_stale(taxonomy)
  end

  private

    def collections
      @collections ||= MasterportalCollection.where(projekt_phase_id: @projekt_phase.id).to_a
    end

    def upsert(taxonomy, collection)
      record = taxonomy.find_or_initialize_by(masterportal_collection_id: collection.id)
      record.name = collection.display_name
      record.icon = DEFAULT_ICON if record.icon.blank?

      if record.is_a?(ProjektPointOfInterestCategory)
        record.color = DEFAULT_COLOR if record.color.blank?
      end

      record.save!

      attach_category_image(record, collection) if record.is_a?(ProjektPointOfInterestCategory)
    rescue ActiveRecord::RecordNotUnique
      nil
    end

    def attach_category_image(category, collection)
      return if category.icon_image.attached?

      image = Masterportal::RemoteIconDownloader.call(url: collection.encoded_icon_url)
      return if image.nil?

      category.icon_image.attach(**image)
    rescue => e
      Sentry.capture_exception(e) if defined?(Sentry)
    end

    def remove_stale(taxonomy)
      taxonomy
        .collection_backed
        .where.not(masterportal_collection_id: collections.map(&:id))
        .destroy_all
    end
end
