namespace :adm do
  root to: "home#show"

  resources :projekts, only: [:index, :show]
end
