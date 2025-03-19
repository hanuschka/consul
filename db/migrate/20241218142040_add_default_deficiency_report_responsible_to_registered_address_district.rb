class AddDefaultDeficiencyReportResponsibleToRegisteredAddressDistrict < ActiveRecord::Migration[6.1]
  def change
    add_reference :registered_address_districts, :default_deficiency_report_responsible, polymorphic: true,
      index: { name: "index_registered_address_districts_on_default_dr_responsible", unique: true }
  end
end
