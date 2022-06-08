class Sidebar::ProjektsFilterCheckboxComponent < ApplicationComponent
  delegate :projekt_filter_resources_name, to: :helpers
  attr_reader :aggregations, :f, :projekt

  def initialize(
    f:,
    projekt:,
    scoped_projekt_ids:,
    group:,
    all_resources:,
    current_projekt: nil,
    aggregations: nil
  )
    @f = f
    @projekt = projekt
    @scoped_projekt_ids = scoped_projekt_ids
    @group = group
    @all_resources = all_resources
    @current_projekt = current_projekt
    @aggregations = aggregations
  end

  private

  def resource_count
    return if params[:controller] == 'search'

    projekt_ids_to_count = projekt.all_children_projekts.unshift(projekt).select do |projekt|
      (projekt.all_children_ids.unshift(projekt.id) & @scoped_projekt_ids).any?
    end

    @all_resources.where( projekt: projekt_ids_to_count ).count
  end

  def selectable_children
    return @projekt.children.activated if params[:controller] == 'search'

    projekt.children.select{ |projekt| ( projekt.all_children_ids.unshift(projekt.id) & @scoped_projekt_ids ).any? }
  end

  def label_class
    if checkbox_checked
      'label-selected'
    else
      'label_regular'
    end
  end

  def checkbox_checked
    selected_projekts_ids = params[:filter_projekt_ids]
    selected_projekts_ids && projekt.id.to_s.in?(selected_projekts_ids)
  end
end
