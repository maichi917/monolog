Rails.application.routes.draw do
  devise_for :users
  root "static_pages#top"

  resources :items, only: %i[index new create edit update destroy]
end
