class Spree::Gateway::PayuGateway < Spree::Gateway
  preference :merchant_pos_id, :string
  preference :signature_key, :string
  preference :algorithm, :string, default: 'MD5'
  preference :service_domain, :string, default: 'payu.com'
  preference :protocol, :string, default: 'https'
  preference :env, :string, default: 'secure'
  # preference :order_url        = ''
  # preference :notify_url       = ''
  # preference :continue_url     = ''

  def supports?(source)
    true
  end

  # def provider_class
  #   # OpenPayu
  #   ::PayPal::SDK::Merchant::API
  # end
  #
  # def provider
  #   ::PayPal::SDK.configure(
  #     :mode      => preferred_server.present? ? preferred_server : "sandbox",
  #     :username  => preferred_login,
  #     :password  => preferred_password,
  #     :signature => preferred_signature)
  #   provider_class.new
  # end

  def auto_capture?
    true
  end

  def method_type
    'payu_gateway'
  end

  def purchase(amount, express_checkout, gateway_options={})
    params = PayuOrder.params(@order, request.remote_ip, order_url(@order), payu_notify_url, order_url(@order))
    response = OpenPayU::Order.create(params)

    # case response.status['status_code']
    # when 'SUCCESS'
    #   redirect_to response.redirect_uri if payment_success(payment_method)
    # else
    #   payu_error
    # end
  end

  def refund(payment, amount)
  end
end
