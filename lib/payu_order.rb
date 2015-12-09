class PayuOrder
  include Rails.application.routes.url_helpers

  def self.params(order, ip, order_url, notify_url, continue_url)
    {
      merchant_pos_id: OpenPayU::Configuration.merchant_pos_id,
      customer_ip: ip,
      ext_order_id: order.id,
      description: description,
      currency_code: order.currency,
      total_amount: (order.total * 100).to_i,
      order_url: order_url,
      notify_url: notify_url,
      continue_url: continue_url,
      buyer: {
        email: order.email,
        phone: order.bill_address.phone,
        first_name: order.bill_address.firstname,
        last_name: order.bill_address.lastname,
        language: 'PL',
        delivery: {
          street: order.shipping_address.address1,
          postal_code: order.shipping_address.zipcode,
          city: order.shipping_address.city,
          country_code: order.bill_address.country.iso,
          recipient_name: "#{order.shipping_address.first_name} #{order.shipping_address.last_name}"
        }
      },
      products: items(order)
    }
  end

  class << self
    private

    def items(order)
      products(order) + shipping(order) + adjustments(order)
    end

    def products(order)
      order.line_items.map do |li|
        {
          name: li.product.name,
          unit_price: (li.price * 100).to_i,
          quantity: li.quantity
        }
      end
    end

    def adjustments(order)
      [].tap do |result|
        result << {name: 'RABAT', unit_price: (order.adjustment_total*100).to_i, quantity: 1} if order.adjustment_total != 0
      end
    end

    def shipping(order)
      [
        {
          quantity: 1,
          unit_price: (order.shipment_total* 100).to_i,
          name: order.shipments.first.shipping_method.name
        }
      ]
    end

    def description
      description = I18n.t('order_description', name: Spree::Store.current.name)
      I18n.transliterate(description)
    end
  end
end
