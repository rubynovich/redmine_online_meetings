# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html
resources :meeting_agendas do
  member do
    get 'issue'
  end
end