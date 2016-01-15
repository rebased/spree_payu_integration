require 'spec_helper'

spree_gem_version = Gem::Version.new(Spree.version)

RSpec.describe Spree::PayuController, type: :controller do
  describe "POST /payu/notify" do
    let!(:order) { OrderWalkthrough.up_to(:address) }
    let(:payment_method) { FactoryGirl.create :payu_payment_method }
    let(:payment) { order.payments.last }
    # real response taken from VCR tape from OpenPayU implementation:
    # https://github.com/PayU/openpayu_ruby/blob/d751ec8db3e97dccf76edd79104f8ae9236e0cbd/spec/cassettes/retrieve_order.yml
    let(:order_retrieve_data) do
      {
        "req_id" => "PAYU-4321", "pageResponse" => nil, "orders" => {
          "orders" => [{
            "shippingMethod" => nil, "description" => "New order", "fee" => nil,
            "status" => payu_status, "merchantPosId" => "114207",
            "notifyUrl" => "http://localhost/", "customerIp" => "127.0.0.1",
            "extOrderId" => order.id, "totalAmount" => 100, "buyer" => nil,
            "orderCreateDate" => 1_401_265_500_678, "orderUrl" => "http://localhost/",
            "validityTime" => 48_000, "payMethod" => nil,
            "products" => {
              "products" => [{
                "version" => nil, "code" => nil, "subMerchantId" => nil,
                "categoryId" => nil, "categoryName" => nil, "quantity" => 1,
                "unitPrice" => 100, "extraInfo" => nil, "weight" => nil,
                "discount" => nil, "name" => "Mouse", "size" => nil
              }]
            }, "currencyCode" => "PLN", "orderId" => "MHQ3MRZKSQ140528GUEST000P01"
          }]
        },
        "version" => "2.0", "redirectUri" => nil,
        "status" => {
          "code" => nil, "codeLiteral" => nil, "statusCode" => "SUCCESS",
          "statusDesc" => "Request processing successful", "severity" => nil,
          "location" => nil
        }, "resId" => nil, "properties" => nil
      }
    end
    let(:payu_status) { "NEW" }

    let(:fake_http_response) do
      double(:fake_response, code: "200", body: order_retrieve_data.to_json)
    end

    before do
      order.payments.create!(payment_method: payment_method, amount: order.total)

      allow(OpenPayU::Configuration).to receive(:merchant_pos_id).and_return("145278")
      allow(OpenPayU::Configuration).to receive(:signature_key).and_return("S3CRET_KEY")

      stub_request(:get, "https://145278:S3CRET_KEY@secure.payu.com/api/v2/orders/R1234")
        .with(headers:
          {
            'Accept-Encoding' => 'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
            'Content-Type' => 'application/json',
            'User-Agent' => 'Ruby'
          }
        )
        .to_return(status: 200, body: order_retrieve_data.to_json, headers: {})
    end

    subject { spree_post :notify, order: { orderId: "R1234" } }

    it "returns correct response for PayU" do
      subject
      expect(response.body).to eq(
        { "resId" => "PAYU-4321", "status" => { "statusCode" => "SUCCESS" } }.to_json
      )
    end

    context "when payment status is not failed nor complete" do
      before { payment.started_processing! }

      describe "when payu_status is COMPLETED" do
        let(:payu_status) { "COMPLETED" }

        it "completes payment" do
          subject
          expect(payment.reload).to be_completed
        end
      end

      describe "when payu_status is CANCELED" do
        let(:payu_status) { "CANCELED" }

        it "completes payment" do
          subject
          expect(payment.reload).to be_failed
        end
      end

      describe "when payu_status is REJECTED" do
        let(:payu_status) { "REJECTED" }

        it "completes payment" do
          subject
          expect(payment.reload).to be_failed
        end
      end
    end

    context "when payment status is complete" do
      describe "when payu_status is COMPLETED" do
        let(:payu_status) { "COMPLETED" }
        before do
          # mimicking completing payment
          payment.started_processing!
          payment.complete!
        end

        it "doesn't change payment" do
          payment_last_change_at = payment.updated_at
          subject
          expect(payment.reload).to be_completed
          expect(payment.updated_at).to be_within(1.second).of(payment_last_change_at)
        end
      end
    end

    context "when payment status is failed" do
      describe "when payu_status is COMPLETED" do
        let(:payu_status) { "COMPLETED" }
        before do
          # mimicking failing payment
          payment.started_processing!
          payment.failure!
        end

        it "doesn't change payment" do
          payment_last_change_at = payment.updated_at
          subject
          expect(payment.reload).to be_failed
          expect(payment.updated_at).to be_within(1.second).of(payment_last_change_at)
        end
      end
    end
  end

  describe 'GET /payu/pay' do
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

    describe "GET /payu/pay" do
      before do
        # we need to fake it because it's returned back with order
        allow(SecureRandom).to receive(:uuid).and_return("36332498-294f-41a1-980c-7b2ec0e3a8a4")
        allow(OpenPayU::Configuration).to receive(:merchant_pos_id).and_return("145278")
        allow(OpenPayU::Configuration).to receive(:signature_key).and_return("S3CRET_KEY")
      end

      subject { spree_post :pay, payment_method_id: payment_method.id }

      context "when payment_method is Payu" do
        let(:payment_method) { FactoryGirl.create :payu_payment_method }

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
                  email: order.email,
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
        end

        context "when PayU order creation returns unexpected status" do
          let(:payu_order_create_status) { "FAIL" }

          it "redirects back to payment step with a flash error message" do
            expect(subject).to redirect_to "http://test.host/checkout/payment"
          end

          it "sets flash error" do
            subject

            expect(flash[:error]).to eq "PayU error"
          end
        end

        [
          WrongConfigurationError,
          HttpStatusException,
          EmptyResponseError,
          WrongSignatureException,
          WrongNotifyRequest,
          NotImplementedException,
          WrongOrderParameters
        ].each do |error_klass|
          context "when #{error_klass} was risen by OpenPayU" do
            let(:error_message) { "Payment timeout!" }

            before do
              error_klass.new(order).tap do |error|
                allow(error).to receive(:message).and_return(error_message)

                allow(OpenPayU::Order).to receive(:create).and_raise(error)
              end
            end

            it "redirects back to payment step with a flash error message" do
              expect(subject).to redirect_to "http://test.host/checkout/payment"
            end

            it "sets flash error" do
              subject

              expect(flash[:error]).to eq "PayU error #{error_message}"
            end
          end
        end
      end

      context "when payment method is not PayU" do
        let(:payment_method) { FactoryGirl.create :check_payment_method }

        it 'raises ActiveRecord::RecordNotFound' do
          expect {
            subject
          }.to raise_error ActiveRecord::RecordNotFound
        end

        it 'does not call api' do
          expect(OpenPayU::Order).not_to receive(:create)

          begin
            subject
          rescue ActiveRecord::RecordNotFound
          end
        end
      end
    end
  end
end
