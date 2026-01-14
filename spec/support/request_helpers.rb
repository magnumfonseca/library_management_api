# frozen_string_literal: true

module RequestHelpers
  def json_response
    JSON.parse(response.body)
  end

  def auth_headers(user)
    token = Warden::JWTAuth::UserEncoder.new.call(user, :user, nil).first
    { 'Authorization' => "Bearer #{token}" }
  end

  def auth_post(path, params: {}, headers: {}, user:)
    post path, params: params, headers: headers.merge(auth_headers(user)), as: :json
  end

  def auth_get(path, params: {}, headers: {}, user:)
    get path, params: params, headers: headers.merge(auth_headers(user)), as: :json
  end

  def auth_patch(path, params: {}, headers: {}, user:)
    patch path, params: params, headers: headers.merge(auth_headers(user)), as: :json
  end

  def auth_put(path, params: {}, headers: {}, user:)
    put path, params: params, headers: headers.merge(auth_headers(user)), as: :json
  end

  def auth_delete(path, params: {}, headers: {}, user:)
    delete path, params: params, headers: headers.merge(auth_headers(user)), as: :json
  end
end

RSpec.configure do |config|
  config.include RequestHelpers, type: :request
end
