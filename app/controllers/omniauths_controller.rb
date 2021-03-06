class OmniauthsController < ApplicationController

  def callback
    auth = request.env['omniauth.auth']
    
    unless auth && auth[:extra][:raw_info][:context]
      return render_error("[install] Invalid credentials: #{JSON.pretty_generate(auth[:extra])}")
    end
    
    app_url  = ENV['APPLICATION_URL']
    email = auth[:info][:email]
    name = auth[:info][:name]
    store_hash = auth[:extra][:context].split('/')[1]
    token = auth[:credentials][:token].token
    scope = auth[:extra][:scopes]

    # Lookup store
    store = Store.where(store_hash: store_hash).first
    
    if store
      logger.info "[install] Updating token for store '#{store_hash}' with scope '#{scope}'"
      store.update(access_token: token, scope: scope)
    else
      logger.info "[install] Installing app for store '#{store_hash}' with admin '#{email}'"
      store = Store.create(store_hash: store_hash, access_token: token, scope: scope, email: email, username: name)
    end
    render 'home/index', locals: { store_info: current_store_info(store) }, status: 200

  end

  def uninstall
    payload = parse_signed_payload
    store = Store.find_by(store_hash: payload["store_hash"])
    store.destroy if store.present?
    Rails.logger.debug "Store Removed successfully"
    render nothing: true, status: 200
  end

  def load
    payload = parse_signed_payload
    @payload = payload
    return render_error('[load] Invalid payload signature!') unless payload

    @email = payload['user']['email']
    store_hash = payload['store_hash']
    
    # Lookup store
    @store = Store.find_by(store_hash: store_hash)
    return render_error("[load] Store not found!") unless @store

    logger.info "[load] Loading app for user '#{@email}' on store '#{store_hash}'"
    render 'home/index', locals: { store_info: current_store_info(@store) }, status: 200
  end

  private

  def parse_signed_payload
    signed_payload = params[:signed_payload]
    encoded_json_payload, encoded_hmac_signature = signed_payload.split('.')

    payload = Base64.decode64(encoded_json_payload)
    provided_signature = Base64.decode64(encoded_hmac_signature)
    expected_signature = sign_payload(bc_client_secret, payload)

    if secure_compare(expected_signature, provided_signature)
      return JSON.parse(payload)
    end
    
    nil
  end

  def sign_payload(secret, payload)
    OpenSSL::HMAC::hexdigest('sha256', secret, payload)
  end

  def bc_client_id
    ENV['BC_CLIENT_ID']
  end

  # Get client secret from env
  def bc_client_secret
    ENV['BC_CLIENT_SECRET']
  end

  # Get the API url from env
  def bc_api_url
    ENV['BC_API_ENDPOINT'] || 'https://api.bigcommerce.com'
  end

  # Full url to this app
  def app_url
    ENV['APP_URL']
  end

  # The scopes we are requesting (must match what is requested in
  # Developer Portal).
  def scopes
    ENV.fetch('SCOPES', 'store_v2_products')
  end

  def secure_compare(a, b)
    return false if a.blank? || b.blank? || a.bytesize != b.bytesize
    l = a.unpack "C#{a.bytesize}"

    res = 0
    b.each_byte { |byte| res |= byte ^ l.shift }
    res == 0
  end

  def render_error(e)
    logger.warn "ERROR: #{e}"
    @error = e

    raise e
  end

end