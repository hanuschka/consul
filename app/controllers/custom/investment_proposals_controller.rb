class InvestmentProposalsController < ApplicationController
  include ProjektControllerHelper

  skip_authorization_check
  PER_PAGE = 10

  def index
    if params[:projekts]
      @selected_projekts_ids = params[:projekts].split(',').select{ |id| Projekt.find_by(id: id).present? }
      selected_parent_projekt_id = get_highest_unique_parent_projekt_id(@selected_projekts_ids)
      @selected_parent_projekt = Projekt.find_by(id: selected_parent_projekt_id)
    end

    @investments = Budget::Investment.all.page(params[:page]).per(PER_PAGE).for_render
    @investment_ids = @investments.pluck(:id)

    @geozones = Geozone.all

    @selected_geozone_affiliation = params[:geozone_affiliation] || 'all_resources'
    @affiliated_geozones = (params[:affiliated_geozones] || '').split(',').map(&:to_i)

    @selected_geozone_restriction = params[:geozone_restriction] || 'no_restriction'
    @restricted_geozones = (params[:restricted_geozones] || '').split(',').map(&:to_i)

    @top_level_active_projekts = Projekt.top_level_active.select{ |projekt| projekt.all_children_projekts.unshift(projekt).any? { |p| p.investment_proposals.any? } }
    @top_level_archived_projekts = Projekt.top_level_archived.select{ |projekt| projekt.all_children_projekts.unshift(projekt).any? { |p| p.investment_proposals.any? } }

    @categories = Tag.category.order(:name)
    @tag_cloud = TagCloud.new(Budget::Investment)

    @filtered_goals = params[:sdg_goals].present? ? params[:sdg_goals].split(',').map{ |code| code.to_i } : nil
    @filtered_target = params[:sdg_targets].present? ? params[:sdg_targets].split(',')[0] : nil

    unless params[:search].present?
      take_only_by_tag_names
      take_by_projekts
      take_by_sdgs
      # take_by_geozone_affiliations
      # take_by_geozone_restrictions
    end

    investment_ids_for_map = @investments.ids
    @investments_map_coordinates = MapLocation.where(investment: investment_ids_for_map).map(&:json_data)
    @investments
  end

  private

  def take_only_by_tag_names
    if params[:tags].present?
      @investments = @investments.tagged_with(params[:tags].split(","), all: true)
    end
  end

  def take_by_projekts
    if params[:projekts].present?
      @investments = @investments.joins(:budget).where(budgets: { projekt: params[:projekts].split(',') } ).distinct
    end
  end

  def take_by_sdgs
    if params[:sdg_targets].present?
      @investments = @investments.joins(:sdg_global_targets).where(sdg_targets: { code: params[:sdg_targets].split(',')[0] }).distinct
      return
    end

    if params[:sdg_goals].present?
      @investments = @investments.joins(:sdg_goals).where(sdg_goals: { code: params[:sdg_goals].split(',') }).distinct
    end
  end

  def take_by_geozone_affiliations
    case @selected_geozone_affiliation
    when 'all_resources'
      @resources
    when 'no_affiliation'
      @resources = @resources.joins(:projekt).where( projekts: { geozone_affiliated: 'no_affiliation' } ).distinct
    when 'entire_city'
      @resources = @resources.joins(:projekt).where(projekts: { geozone_affiliated: 'entire_city' } ).distinct
    when 'only_geozones'
      @resources = @resources.joins(:projekt).where(projekts: { geozone_affiliated: 'only_geozones' } ).distinct
      if @affiliated_geozones.present?
        @resources = @resources.joins(:geozone_affiliations).where(geozones: { id: @affiliated_geozones }).distinct
      else
        @resources = @resources.joins(:geozone_affiliations).where.not(geozones: { id: nil }).distinct
      end
    end
  end

  def take_by_geozone_restrictions
    case @selected_geozone_restriction
    when 'no_restriction'
      @resources = @resources.joins(:proposal_phase).distinct
    when 'only_citizens'
      @resources = @resources.joins(:proposal_phase).where(projekt_phases: { geozone_restricted: ['only_citizens', 'only_geozones'] }).distinct
    when 'only_geozones'
      @resources = @resources.joins(:proposal_phase).where(projekt_phases: { geozone_restricted: 'only_geozones' }).distinct

      if @restricted_geozones.present?
        sql_query = "
          INNER JOIN projekts AS projekts_proposals_join_for_restrictions ON projekts_proposals_join_for_restrictions.hidden_at IS NULL AND projekts_proposals_join_for_restrictions.id = proposals.projekt_id
          INNER JOIN projekt_phases AS proposal_phases_proposals_join_for_restrictions ON proposal_phases_proposals_join_for_restrictions.projekt_id = projekts_proposals_join_for_restrictions.id AND proposal_phases_proposals_join_for_restrictions.type IN ('ProjektPhase::ProposalPhase')
          INNER JOIN projekt_phase_geozones ON projekt_phase_geozones.projekt_phase_id = proposal_phases_proposals_join_for_restrictions.id
          INNER JOIN geozones AS geozone_restrictions ON geozone_restrictions.id = projekt_phase_geozones.geozone_id
        "
        @resources = @resources.joins(sql_query).where(geozone_restrictions: { id: @restricted_geozones }).distinct
      end
    end
  end
end
