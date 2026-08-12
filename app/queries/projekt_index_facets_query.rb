class ProjektIndexFacetsQuery
  # Sidebar facets for the projekts overview page. Each facet is derived with
  # one aggregate query against the currently filtered scope, so building the
  # sidebar never materialises the projekts themselves.
  #
  # The ordering here is not cosmetic: it reproduces what the previous Ruby
  # derivation produced, so the rendered sidebar is unchanged.
  #   - category tags were `.sort`ed, and Tag inherits `<=>` from
  #     ActiveRecord::Core, which compares by id
  #   - phase types feed a list that is re-sorted by PROJEKT_PHASES_TYPES

  def self.category_tags(projekts)
    Tag
      .joins(:taggings)
      .where(taggings: { taggable_type: "Projekt", taggable_id: projekt_ids(projekts), context: "tags" })
      .where(kind: "category")
      .distinct
      .reorder(:id)
      .to_a
  end

  def self.phase_types(projekts)
    ProjektPhase
      .active
      .frontend_visible
      .where(projekt_id: projekt_ids(projekts))
      .unscope(:order)
      .distinct
      .pluck(Arel.sql("projekt_phases.type"))
      .compact
  end

  # `except` rather than `unscope`, which rejects :preload as an argument.
  def self.projekt_ids(projekts)
    projekts.except(:preload, :includes, :eager_load).select(:id)
  end

  private_class_method :projekt_ids
end
