Spree::Core::Engine.routes.draw do
  post '/payu/notify', to: 'payu#notify'
  get '/payu/pay', to: 'payu#pay', as: :pay_with_payu
end
