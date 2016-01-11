module Spree
  class PayuController < Spree::BaseController
    protect_from_forgery except: :notify

    [
      WrongConfigurationError,
      HttpStatusException,
      EmptyResponseError,
      WrongSignatureException,
      WrongNotifyRequest,
      NotImplementedException,
      WrongOrderParameters
    ].each do |error_klass|
      rescue_from error_klass, with: :payu_error
    end

    def notify
      response = OpenPayU::Order.retrieve(params[:order][:orderId])
      order_info = response.parsed_data['orders']['orders'].first
      order = Spree::Order.find(order_info['extOrderId'])
      payment = order.payments.last

      unless payment.completed? || payment.failed?
        case order_info['status']
        when 'CANCELED', 'REJECTED'
          payment.failure!
        when 'COMPLETED'
          payment.complete!
        end
      end

      render json: OpenPayU::Order.build_notify_response(response.req_id)
    end

    def pay
      if current_order.blank? || current_order.state != 'payment'
        raise ActiveRecord::RecordNotFound
      end

      params = PayuOrder.params(current_order, request.remote_ip, order_url(current_order), payu_notify_url, order_url(current_order))
      response = OpenPayU::Order.create(params)

      case response.status['status_code']
      when 'SUCCESS'
        redirect_to response.redirect_uri if payment_success
      else
        payu_error
      end
    end

    private

    def payment_success
      payment_method = Spree::PaymentMethod.find(params[:payment_method_id])

      payment = current_order.payments.build(
        payment_method_id: payment_method.id,
        amount: current_order.total,
        state: 'checkout'
      )

      unless payment.save
        flash[:error] = payment.errors.full_messages.join("\n")
        redirect_to checkout_state_path(current_order.state) and return
      end

      unless current_order.next
        flash[:error] = current_order.errors.full_messages.join("\n")
        redirect_to checkout_state_path(current_order.state) and return
      end

      payment.pend!
    end

    def payu_error(e = nil)
      error = ["PayU error", e.try(:message)].compact.join(' ');
      flash[:error] = error

      redirect_to checkout_state_path(current_order.state)
    end
  end
end
