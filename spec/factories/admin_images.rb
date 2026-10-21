FactoryBot.define do
  factory :admin_image do
    transient do
      fixture_path { Rails.root.join("spec", "fixtures", "files", "clippy.jpg") }
    end

    data_file_name { "clippy.jpg" }
    data_content_type { "image/jpeg" }
    data_file_size { File.size(fixture_path) }
    title { "clippy.jpg" }

    after(:build) do |admin_image, evaluator|
      next if admin_image.storage_data.attached?

      admin_image.storage_data.attach(
        io: StringIO.new(evaluator.fixture_path.binread),
        filename: admin_image.data_file_name,
        content_type: admin_image.data_content_type
      )
    end
  end
end
