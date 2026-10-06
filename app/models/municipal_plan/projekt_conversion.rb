class MunicipalPlan::ProjektConversion
  include ActiveModel::Model

  attr_accessor :name, :subtitle
  attr_reader :municipal_plan, :projekt

  validate :name_present
  validate :subtitle_within_limits

  def self.prefilled_for(municipal_plan)
    new(municipal_plan,
        name: municipal_plan.title,
        subtitle: plain_subtitle(municipal_plan.short_description))
  end

  def self.plain_subtitle(html)
    normalized = MultilineSubtitleNormalizer.normalize(html)
    with_newlines = normalized.gsub(MultilineSubtitleNormalizer::BR_REGEX, "\n")
    CGI.unescapeHTML(ActionController::Base.helpers.strip_tags(with_newlines))
  end

  def initialize(municipal_plan, attributes = {})
    @municipal_plan = municipal_plan
    super(attributes)
  end

  def save(author:)
    return false if invalid?

    ActiveRecord::Base.transaction do
      @projekt = Projekt.create!(name: name, author: author, municipal_plan: municipal_plan)
      @projekt.page.update!(subtitle: subtitle)
      copy_districts
      copy_map_location
    end

    true
  rescue ActiveRecord::RecordInvalid => e
    e.record.errors.full_messages.each { |message| errors.add(:base, message) }
    @projekt = nil
    false
  end

  private

    def name_present
      return if name.present?

      errors.add(:base, I18n.t("adm.municipal_plans.projekt_conversions.errors.name_blank"))
    end

    def subtitle_within_limits
      normalizer = MultilineSubtitleNormalizer
      normalized = normalizer.normalize(subtitle)

      if normalizer.visible_length(normalized) > normalizer::MAX_VISIBLE_LENGTH
        errors.add(:base, I18n.t("adm.municipal_plans.projekt_conversions.errors.subtitle_too_long",
                                 count: normalizer::MAX_VISIBLE_LENGTH))
      end

      if normalizer.line_break_count(normalized) > normalizer::MAX_LINE_BREAKS
        errors.add(:base, I18n.t("adm.municipal_plans.projekt_conversions.errors.subtitle_too_many_lines",
                                 count: normalizer::MAX_LINE_BREAKS + 1))
      end
    end

    def copy_districts
      district_ids = municipal_plan.district_ids
      return if district_ids.empty?

      @projekt.update!(geozone_affiliated: "only_geozones",
                       registered_address_district_affiliation_ids: district_ids)
    end

    def copy_map_location
      source = municipal_plan.map_location
      return if source.blank?

      target = @projekt.map_location || @projekt.build_map_location
      target.assign_attributes(
        latitude: source.latitude,
        longitude: source.longitude,
        zoom: source.zoom,
        features: source.features.presence || {},
        approximated_address: source.approximated_address,
        geocoder_data: source.geocoder_data
      )
      target.skip_masterportal_geocoding = true
      target.save!
    end
end
