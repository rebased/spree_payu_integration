/* Placeholder for backend dummy app */
(function($) {
  SpreePayuIntegration = {
    updateSaveAndContinueVisibility: function(e) {
      if (this.isPayuChoosen(e)) {
        console.log('yes');
        this.hideSaveAndContinue();
      } else {
        console.log('no');
        this.showSaveAndContinue();
      }
    },

    isPayuChoosen: function(e) {
      return this.choosenPaymentMethodId(e) == this.payuPaymentMethodId();
    },

    choosenPaymentMethodId: function(e) {
      if (e) {
        return $(e.target).val();
      }

      return $('[name="order[payments_attributes][][payment_method_id]').val();
    },

    payuPaymentMethodId: function() {
      return $('#payu_button').data('payment-method-id');
    },

    hideSaveAndContinue: function() {
      $('[data-hook="buttons"] button').hide();
    },

    showSaveAndContinue: function() {
      $('[data-hook="buttons"] button').show();
    }
  }

  $(document).ready(function() {
    SpreePayuIntegration.updateSaveAndContinueVisibility();

    var onPaymentMethodChange = SpreePayuIntegration.updateSaveAndContinueVisibility.bind(SpreePayuIntegration);
    $('div[data-hook="checkout_payment_step"] input[type="radio"]').click(onPaymentMethodChange);
  })
})(jQuery);
