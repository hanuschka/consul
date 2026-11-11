class Api::Configuration::NavbarItemsController < Api::Configuration::BaseController
  ATTRIBUTE_DEFINITIONS = {
    "kind" => TypedValueParser::Definition.new(type: :select, options: NavbarItem.kinds.keys),
    "preset" => TypedValueParser::Definition.new(
      type: :select, options: NavbarItem::PRESETS.keys.map(&:to_s), allow_blank: true
    ),
    "projekt_id" => TypedValueParser::Definition.new(type: :integer, min: 1, allow_blank: true),
    "linked_page_id" => TypedValueParser::Definition.new(type: :integer, min: 1, allow_blank: true),
    "landing_page_id" => TypedValueParser::Definition.new(type: :integer, min: 1, allow_blank: true),
    "parent_id" => TypedValueParser::Definition.new(type: :integer, min: 1, allow_blank: true),
    "custom_title" => TypedValueParser::Definition.new(type: :string, allow_blank: true),
    "external_url" => TypedValueParser::Definition.new(type: :url, allow_blank: true),
    "position" => TypedValueParser::Definition.new(type: :integer, min: 0),
    "open_in_new_tab" => TypedValueParser::Definition.new(type: :boolean)
  }.freeze

  before_action :find_navbar_item, only: [:show, :update, :destroy]

  def index
    navbar_items = paginate(
      filtered_navbar_items
        .includes(projekt: :translations, linked_page: :translations)
        .order(Arel.sql("parent_id IS NOT NULL"), :parent_id, :position, :id)
    )

    render json: {
      data: { navbar_items: navbar_items.map { |navbar_item| serialize(navbar_item) } },
      pagination: pagination_meta(navbar_items)
    }
  end

  def show
    render json: { data: { navbar_item: serialize(@navbar_item) } }
  end

  def create
    save_navbar_item(NavbarItem.new, status: :created)
  end

  def update
    save_navbar_item(@navbar_item, status: :ok)
  end

  def destroy
    @navbar_item.destroy!

    head :no_content
  end

  private

    def find_navbar_item
      @navbar_item = NavbarItem.find(params[:id])
    end

    def filtered_navbar_items
      if params[:landing_page_id].present?
        NavbarItem.for_landing_page(params[:landing_page_id].to_s.to_i)
      else
        NavbarItem.global
      end
    end

    def save_navbar_item(navbar_item, status:)
      raw_attributes = params.require(:navbar_item).to_unsafe_h
      attribute_values, errors = parse_typed_attributes(raw_attributes, ATTRIBUTE_DEFINITIONS)
      errors.merge!(unknown_attribute_errors(raw_attributes, ATTRIBUTE_DEFINITIONS.keys))
      navbar_item.assign_attributes(attribute_values)
      errors = reference_errors(navbar_item).merge(errors)

      if errors.any?
        return render_invalid_values(errors)
      end

      if navbar_item.save
        render json: { data: { navbar_item: serialize(navbar_item.reload) } }, status:
      else
        render_record_errors(navbar_item)
      end
    end

    # The model only checks that a kind is set; what the kind points at is
    # checked here, so an item cannot link to a projekt or page that is gone.
    def reference_errors(navbar_item)
      errors = {}

      if navbar_item.kind.blank?
        errors["kind"] = ["can't be blank"]
      end

      if navbar_item.landing_page_id && !landing_page_exists?(navbar_item.landing_page_id)
        errors["landing_page_id"] = ["is not a landing page"]
      end

      errors.merge!(kind_target_errors(navbar_item))
      errors.merge!(parent_errors(navbar_item))

      errors
    end

    def kind_target_errors(navbar_item)
      case navbar_item.kind
      when "presets" then preset_errors(navbar_item)
      when "projekts" then projekt_errors(navbar_item)
      when "landing_pages" then linked_page_errors(navbar_item)
      when "external" then external_url_errors(navbar_item)
      else {}
      end
    end

    def preset_errors(navbar_item)
      allowed_presets =
        if navbar_item.landing_page_id
          NavbarItem::LANDING_PAGE_ALLOWED_PRESETS.map(&:to_s)
        else
          NavbarItem::PRESETS.keys.map(&:to_s)
        end

      if allowed_presets.include?(navbar_item.preset.to_s)
        {}
      else
        { "preset" => ["must be one of: #{allowed_presets.join(", ")}"] }
      end
    end

    def projekt_errors(navbar_item)
      if navbar_item.projekt_id && Projekt.exists?(navbar_item.projekt_id)
        {}
      else
        { "projekt_id" => ["must be an existing projekt"] }
      end
    end

    def linked_page_errors(navbar_item)
      if navbar_item.linked_page_id && landing_page_exists?(navbar_item.linked_page_id)
        {}
      else
        { "linked_page_id" => ["must be an existing landing page"] }
      end
    end

    def external_url_errors(navbar_item)
      if navbar_item.external_url.present?
        {}
      else
        { "external_url" => ["can't be blank for external items"] }
      end
    end

    def parent_errors(navbar_item)
      return {} if navbar_item.parent_id.nil?

      parent = NavbarItem.find_by(id: navbar_item.parent_id)

      if parent.nil? || parent.id == navbar_item.id
        { "parent_id" => ["must be another existing navbar item"] }
      elsif parent.landing_page_id != navbar_item.landing_page_id
        { "parent_id" => ["must belong to the same navigation"] }
      else
        {}
      end
    end

    def landing_page_exists?(page_id)
      ::SiteCustomization::Page.landing.exists?(page_id)
    end

    def serialize(navbar_item)
      {
        id: navbar_item.id,
        kind: navbar_item.kind,
        preset: navbar_item.preset,
        projekt_id: navbar_item.projekt_id,
        linked_page_id: navbar_item.linked_page_id,
        landing_page_id: navbar_item.landing_page_id,
        parent_id: navbar_item.parent_id,
        position: navbar_item.position,
        custom_title: navbar_item.custom_title,
        title: navbar_item.title,
        external_url: navbar_item.external_url,
        open_in_new_tab: navbar_item.open_in_new_tab,
        created_at: navbar_item.created_at,
        updated_at: navbar_item.updated_at
      }
    end
end
