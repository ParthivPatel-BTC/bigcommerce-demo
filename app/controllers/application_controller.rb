class ApplicationController < ActionController::Base
  
  protect_from_forgery with: :exception
  after_filter :set_header_for_iframe
  helper_method :current_store
  helper_method :current_connection
  
  # require to remove X-Frame-Options to load Rails app in iframe on Bigcommerce
  def set_header_for_iframe
    response.headers.delete "X-Frame-Options"
  end

  def current_store_info(store)
    connection = Bigcommerce::Connection.build(Bigcommerce::Config.new(store_hash: store.store_hash , client_id: ENV['BC_CLIENT_ID'], access_token: store.access_token))
    JSON.parse(connection.get("/stores/#{store_hash}/v2/store").body)
  end

end
