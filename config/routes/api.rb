  namespace :api do
    resources :projekts do
      resources :projekt_phases
      resources :content_blocks do
        collection do
          post :reorder
        end
      end
    end
  end
