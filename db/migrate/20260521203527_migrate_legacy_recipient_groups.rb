class MigrateLegacyRecipientGroups < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    RecipientGroup.find_each do |rg|
      next if rg.filters.exists?

      attrs = legacy_to_filter_attrs(rg)
      next unless attrs

      rg.filters.create!(attrs.merge(position: 1, operator: "include"))
    end
  end

  def down
    # Non-reversible: filter chains may have been edited after migration.
    raise ActiveRecord::IrreversibleMigration
  end

  private

    def legacy_to_filter_attrs(rg)
      case [rg.origin_class_name, rg.access_method]
      in ["User", "newsletter_subscriber_ids"]
        { kind: "newsletter_subscribers", params: { "include_unregistered" => false } }
      in ["User", "all_newsletter_subscriber_ids"]
        { kind: "newsletter_subscribers", params: { "include_unregistered" => true } }
      in ["User", "administrators_ids"]
        { kind: "role", params: { "role" => "administrator" } }
      in ["Projekt", "any_phase_subscribers_ids"]
        { kind: "phase_subscribers", params: { "projekt_id" => rg.origin_class_object_id.to_i } }
      in ["ProjektPhase", method] if method.start_with?("authors_of_") && method.end_with?("_ids")
        criterion = method.sub("authors_of_", "").sub("_ids", "")
        { kind: "phase_authors",
          params: { "projekt_phase_id" => rg.origin_class_object_id.to_i, "criterion" => criterion } }
      else
        nil
      end
    end
end
