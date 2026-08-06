namespace :whatsapp_api, path: "whatsapp_api" do
  post "webhook", to: "webhooks#create"
end
