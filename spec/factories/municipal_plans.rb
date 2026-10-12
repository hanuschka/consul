FactoryBot.define do
  factory :municipal_plan_topic, class: "MunicipalPlan::Topic" do
    sequence(:name) { |n| "Thema #{n}" }
  end

  factory :municipal_plan_officer, class: "MunicipalPlan::Officer" do
    user
  end

  factory :municipal_plan_officer_group, class: "MunicipalPlan::OfficerGroup" do
    sequence(:name) { |n| "Fachbereich #{n}" }
  end

  factory :municipal_plan_officer_group_assignment, class: "MunicipalPlan::OfficerGroupAssignment" do
    officer factory: :municipal_plan_officer
    officer_group factory: :municipal_plan_officer_group
  end

  factory :municipal_plan do
    sequence(:title) { |n| "Vorhaben #{n}" }
    short_description { "Kurze Beschreibung" }
    processing_status { "In Bearbeitung" }
    next_steps { "Nächste Schritte" }
    association :responsible, factory: :municipal_plan_officer

    after(:build) do |plan|
      plan.map_location ||= build(:map_location, mappable: plan)

      if plan.district_assignments.empty?
        plan.district_assignments.build(district: create(:registered_address_district))
      end

      if plan.topic_assignments.empty?
        plan.topic_assignments.build(topic: create(:municipal_plan_topic))
      end
    end

    trait :published do
      status { "published" }
    end
  end
end
