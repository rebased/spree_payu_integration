require 'spec_helper'

spree_gem_version = Gem::Version.new(Spree.version)

RSpec.describe Spree::CheckoutController, type: :controller do
  # copied from original checkout controller spec
  let(:token) { 'some_token' }
  let(:user) { FactoryGirl.create(:user) }
  let(:order) do
    # the following if statement was created as a workaround for this commit
    # https://github.com/spree/spree/commit/a301559bc3d0baf139cc2b5b8475935e15843ed1
    if spree_gem_version > Gem::Version.new('3.0.2')
      OrderWalkthrough.up_to(:payment)
    else
      OrderWalkthrough.up_to(:delivery)
    end
  end

  before do
    allow_any_instance_of(ActionDispatch::Request).to receive(:remote_ip).and_return("128.0.0.1")
    allow(controller).to receive(:try_spree_current_user).and_return(user)
    allow(controller).to receive(:spree_current_user).and_return(user)
    allow(controller).to receive(:current_order).and_return(order)
    allow(PayuOrder).to receive(:description).and_return('description')
  end

  describe "PATCH /checkout/update/payment" do
    context "when payment_method is PayU" do
      let(:payment_method) { FactoryGirl.create :payu_payment_method }

      let(:payment_params) do
        {
          state: "payment",
          order: { payments_attributes: [{ payment_method_id: payment_method.id }] }
        }
      end

      subject { spree_post :update, payment_params }

      before do
        # we need to fake it because it's returned back with order
        allow(SecureRandom).to receive(:uuid).and_return("36332498-294f-41a1-980c-7b2ec0e3a8a4")
        allow(OpenPayU::Configuration).to receive(:merchant_pos_id).and_return("145278")
        allow(OpenPayU::Configuration).to receive(:signature_key).and_return("S3CRET_KEY")
      end

      let(:payu_order_create_status) { "SUCCESS" }

      let!(:payu_order_create) do
        stub_request(:post, "https://145278:S3CRET_KEY@secure.payu.com/api/v2/orders")
          .with(body:
            {
              merchantPosId: "145278",
              customerIp: "128.0.0.1",
              extOrderId: order.id,
              description: 'description',
              currencyCode: "USD",
              totalAmount: (order.total*100).to_i,
              orderUrl: "http://test.host/orders/#{order.number}",
              notifyUrl: "http://test.host/payu/notify",
              continueUrl: "http://test.host/orders/#{order.number}",
              buyer: {
                email: user.email,
                phone: order.bill_address.phone,
                firstName: order.bill_address.firstname,
                lastName: order.bill_address.lastname,
                language: 'PL',
                delivery: {
                    street: order.shipping_address.address1,
                    postalCode: order.shipping_address.zipcode,
                    city: order.shipping_address.city,
                    countryCode: order.bill_address.country.iso,
                    recipientName: order.shipping_address.first_name + " " + order.shipping_address.last_name
                }
              },
              products: {
                products: [
                  { name: order.line_items.first.product.name, unitPrice: (order.line_items.first.price*100).to_i, quantity: 1 },
                  { name: 'UPS Ground', unitPrice: 1000, quantity: 1 }
                ]
              },
              reqId: "{36332498-294f-41a1-980c-7b2ec0e3a8a4}"
            },
            headers: { 'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Content-Type' => 'application/json', 'User-Agent' => 'Ruby' }
          )
          .to_return(
            status: 200,
            body: {
              status: { statusCode: payu_order_create_status },
              redirect_uri: "http://payu.com/redirect/url/4321"
            }.to_json,
            headers: {}
          )
      end

      it "creates new PayU order" do
        expect { subject }.to_not raise_error
        expect(payu_order_create).to have_been_requested
      end

      context "when PayU order creation succeeded" do
        it "updates order payment" do
          subject
          payment = order.payments.last
          expect(payment.payment_method).to eq(payment_method)
          expect(payment).to be_pending
          expect(payment.amount).to eq(order.total)
        end

        it "redirects to payu redirect url" do
          expect(subject).to redirect_to("http://payu.com/redirect/url/4321")
        end

        context "when payment save failed" do
          before do
            allow_any_instance_of(Spree::Payment).to receive(:save).and_return(false)
            allow_any_instance_of(Spree::Payment).to receive(:errors)
              .and_return(double(full_messages: ["payment save failed"]))
          end

          it "logs errors" do
            subject
            expect(flash[:error]).to include("payment save failed")
          end

          it "renders checkout state with redirect" do
            expect(subject).to redirect_to "http://test.host/checkout/payment"
          end
        end

        context "when order transition failed" do
          before do
            allow(order).to receive(:next).and_return(false)
            allow(order).to(receive(:errors)
              .and_return(double(full_messages: ["order cannot transition to this state"])))
          end

          it "logs errors" do
            subject
            expect(flash[:error]).to include("order cannot transition to this state")
          end

          it "renders checkout state with redirect" do
            expect(subject).to redirect_to "http://test.host/checkout/payment"
          end
        end
      end

      context "when PayU order creation returns unexpected status" do
        let(:payu_order_create_status) { "FAIL" }

        it "logs error in order" do
          subject
          expect(assigns(:order).errors[:base]).to include("PayU error ")
        end

        it "renders :edit page" do
          expect(subject).to render_template(:edit)
        end
      end

      context "when something failed inside PayU order creation" do
        before do
          allow(OpenPayU::Order).to receive(:create).and_raise(RuntimeError.new("Payment timeout!"))
        end

        it "logs error in order" do
          subject
          expect(assigns(:order).errors[:base]).to include("PayU error Payment timeout!")
        end

        it "renders :edit page" do
          expect(subject).to render_template(:edit)
        end
      end
    end

    context "when order attributes are missing" do
      let(:payment_params) { { state: "payment", order: { some: "details" } } }
      subject { spree_post :update, payment_params }

      it "renders checkout state with redirect" do
        expect(subject).to redirect_to "http://test.host/checkout/payment"
      end

      it "logs error" do
        subject
        expect(flash[:error]).to include("No payment found")
      end
    end
  end
end
