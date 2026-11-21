class RecipientGroups::EnsureProjektSubscribersGroup < ApplicationService
  def initialize(projekt)
    @projekt = projekt
  end

  def call
    RecipientGroup.find_by(projekt_id: @projekt.id) || create_group
  end

  private

    def create_group
      RecipientGroup.create_or_find_by!(projekt_id: @projekt.id) do |group|
        group.name = I18n.t(
          "adm.recipient_groups.projekt_subscribers_group_name",
          title: @projekt.title,
          locale: I18n.default_locale
        )
        group.filters.build(
          kind: "projekt_subscribers",
          operator: "include",
          params: { "projekt_id" => @projekt.id.to_s }
        )
      end
    end
end
