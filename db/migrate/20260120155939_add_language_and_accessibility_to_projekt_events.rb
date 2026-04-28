class AddLanguageAndAccessibilityToProjektEvents < ActiveRecord::Migration[6.1]
  def change
    add_column :projekt_events, :language, :string
    add_column :projekt_events, :wheelchair_accessible, :boolean, default: false
    add_column :projekt_events, :accessible_toilet, :boolean, default: false
    add_column :projekt_events, :disabled_parking_nearby, :boolean, default: false
    add_column :projekt_events, :tactile_guidance_systems, :boolean, default: false
    add_column :projekt_events, :induction_loop_available, :boolean, default: false
    add_column :projekt_events, :assistance_dogs_welcome, :boolean, default: false
    add_column :projekt_events, :sign_language_interpreter, :boolean, default: false
  end
end
