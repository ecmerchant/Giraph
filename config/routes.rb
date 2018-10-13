require 'resque/server'

Rails.application.routes.draw do

  root to: 'products#show'
  get 'products/show'

  get 'products/exchange'

  get 'products/calculate'

  get 'products/setup'
  post 'products/setup'

  get 'products/customize'
  post 'products/customize'

  post 'products/shipping'
  post 'products/import'

  get 'products/report'
  get 'products/get_jp_price'
  get 'products/get_jp_info'

  get 'products/get_us_price'

  mount Resque::Server.new, at: "/resque"

  devise_scope :user do
    get '/users/sign_out' => 'devise/sessions#destroy'
    get '/sign_in' => 'devise/sessions#new'
  end
  mount RailsAdmin::Engine => '/admin', as: 'rails_admin'
  devise_for :users, :controllers => {
   :registrations => 'users/registrations'
  }
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
end
