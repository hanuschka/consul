  namespace :api do
    resources :projekts do
      resources :projekt_phases
    end
  end
