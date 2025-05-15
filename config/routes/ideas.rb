resources :ideas, except: [:edit, :update, :destroy] do
  member do
    get :json_data
    post :vote
    post :unvote
  end

  collection do
    get :suggest
  end
end
