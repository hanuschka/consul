namespace :api do
  desc "Generate API documentation (Swagger/OpenAPI)"
  task generate_docs: :environment do
    puts "Generating API documentation..."

    system("RAILS_ENV=test rails rswag") || abort("Failed to generate Swagger documentation")

    source_file = Rails.root.join("swagger", "v1", "swagger.yaml")
    destination_file = Rails.root.join("public", "openapi.yaml")

    if File.exist?(source_file)
      FileUtils.cp(source_file, destination_file)
      puts "Successfully copied swagger.yaml to public/openapi.yaml"
      puts "API documentation generated successfully!"
    else
      abort("Error: #{source_file} not found. Make sure rswag generated the file correctly.")
    end
  end
end
