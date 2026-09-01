FactoryBot.define do
  factory :deficiency_report do
    sequence(:title) { |n| "Deficiency report #{n}" }
    description      { "Something is broken and needs fixing" }
    resource_terms   { "1" }

    association :author, factory: :user
    association :category, factory: :deficiency_report_category

    # A map location is mandatory on create unless the client turned the setting off, so the factory
    # carries one instead of relying on that setting's value in the test database.
    after(:build) do |report|
      report.map_location ||= build(:map_location, mappable: report)
    end

    trait :on_behalf_of do
      on_behalf_of { "Erika Mustermann" }
    end
  end

  factory :deficiency_report_category, class: "DeficiencyReport::Category" do
    sequence(:name) { |n| "Category #{n}" }
  end

  factory :deficiency_report_subcategory, class: "DeficiencyReport::Subcategory" do
    sequence(:name) { |n| "Subcategory #{n}" }

    association :category, factory: :deficiency_report_category
  end

  factory :deficiency_report_intake_channel, class: "DeficiencyReport::IntakeChannel" do
    sequence(:name) { |n| "Intake channel #{n}" }
  end

  factory :deficiency_report_watch, class: "DeficiencyReport::Watch" do
    deficiency_report
    user
  end

  factory :deficiency_report_status, class: "DeficiencyReport::Status" do
    sequence(:title) { |n| "Status #{n}" }
  end

  factory :deficiency_report_officer, class: "DeficiencyReport::Officer" do
    user
  end

  factory :deficiency_report_officer_group, class: "DeficiencyReport::OfficerGroup" do
    sequence(:name) { |n| "Officer group #{n}" }
  end

  factory :deficiency_report_officer_group_assignment, class: "DeficiencyReport::OfficerGroupAssignment" do
    association :officer, factory: :deficiency_report_officer
    association :officer_group, factory: :deficiency_report_officer_group
  end
end
