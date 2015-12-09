require 'spec_helper'

RSpec.describe PayuOrder, type: :lib do
  describe "#params" do
    let(:order) { OrderWalkthrough.up_to(:payment) }
    let(:order_url) { "http://localhost:5252/order_url/1234" }
    let(:notify_url) { "http://localhost:5252/order_url/notify/1234" }
    let(:continue_url) { "http://localhost:5252/order_url/checkout/continue" }

    let(:current_store) { FactoryGirl.create(:store, name: "My shop") }

    before do
      I18n.locale = :en
      allow(OpenPayU::Configuration).to receive(:merchant_pos_id).and_return("145228")
      allow(Spree::Store).to receive(:current).and_return(current_store)
    end

    subject { described_class.params(order, "128.0.0.1", order_url, notify_url, continue_url) }

    it "returns well structured hash from real order" do
      expect(subject).to eq(
        merchant_pos_id: "145228",
        customer_ip: "128.0.0.1",
        ext_order_id: 1,
        description: "Order from My shop",
        currency_code: "USD",
        total_amount: (order.total*100).to_i,
        order_url: "http://localhost:5252/order_url/1234",
        notify_url: "http://localhost:5252/order_url/notify/1234",
        continue_url: "http://localhost:5252/order_url/checkout/continue",
        buyer: {
          email: "spree@example.com",
          phone: order.bill_address.phone,
          first_name: "John",
          last_name: "Doe",
          language: "PL",
          delivery: {
            street: "10 Lovely Street",
            postal_code: "35005",
            city: "Herndon",
            country_code: "US",
            recipient_name: "John Doe"
          }
        },
        products: [
          {
            name: order.line_items.first.product.name,
            unit_price: (order.line_items.first.price*100).to_i,
            quantity: 1
          },
          {:quantity=>1, :unit_price=>1000, :name=>"UPS Ground"}
        ]
      )

      expect(subject[:products][0][:name]).to be_present
    end
  end
end
