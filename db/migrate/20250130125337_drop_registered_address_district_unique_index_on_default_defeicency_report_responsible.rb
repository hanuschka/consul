class DropRegisteredAddressDistrictUniqueIndexOnDefaultDefeicencyReportResponsible < ActiveRecord::Migration[6.1]
  def up
    remove_index :registered_address_districts,
                 name: "index_registered_address_districts_on_default_dr_responsible"

    add_index :registered_address_districts,
              [:default_deficiency_report_responsible_type, :default_deficiency_report_responsible_id],
              name: "index_registered_address_districts_on_default_dr_responsible"
  end

  def down
    remove_index :registered_address_districts,
                 name: "index_registered_address_districts_on_default_dr_responsible"

    add_index :registered_address_districts,
              [:default_deficiency_report_responsible_type, :default_deficiency_report_responsible_id],
              name: "index_registered_address_districts_on_default_dr_responsible"
  end
end
