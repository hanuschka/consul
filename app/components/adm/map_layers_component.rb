class Adm::MapLayersComponent < ApplicationComponent
  def initialize(map_layers:, mappable:)
    @map_layers = map_layers
    @mappable = mappable
  end

  attr_reader :map_layers, :mappable

  def new_path
    case mappable
    when Projekt
      helpers.new_adm_projekts_projekt_map_layer_path(mappable)
    when ProjektPhase
      helpers.new_adm_projekts_phase_map_layer_path(mappable)
    else
      helpers.new_adm_map_layer_path
    end
  end

  def edit_path(layer)
    case mappable
    when Projekt
      helpers.edit_adm_projekts_projekt_map_layer_path(mappable, layer)
    when ProjektPhase
      helpers.edit_adm_projekts_phase_map_layer_path(mappable, layer)
    else
      helpers.edit_adm_map_layer_path(layer)
    end
  end

  def destroy_path(layer)
    case mappable
    when Projekt
      helpers.adm_projekts_projekt_map_layer_path(mappable, layer)
    when ProjektPhase
      helpers.adm_projekts_phase_map_layer_path(mappable, layer)
    else
      helpers.adm_map_layer_path(layer)
    end
  end
end
