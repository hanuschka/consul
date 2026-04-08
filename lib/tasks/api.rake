namespace :api do
  desc "Generate API documentation (Swagger/OpenAPI)"
  task generate_docs: :environment do
    puts "Generating API documentation...📜"

    system("RAILS_ENV=test rails rswag") || abort("Failed to generate Swagger documentation")
  end
end
