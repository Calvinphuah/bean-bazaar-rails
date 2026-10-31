class ApplicationController < ActionController::API
  rescue_from BeanBazaar::IllegalMove do |error|
    render json: { error: error.message }, status: :unprocessable_content
  end
end
