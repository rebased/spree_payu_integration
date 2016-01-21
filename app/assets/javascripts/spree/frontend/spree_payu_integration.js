/* Placeholder for backend dummy app */
(function($) {
  SpreePayuIntegration = {
    updateSaveAndContinueVisibility: function() {
      if (this.isPayuChoosen()) {
        this.hideSaveAndContinue();
      } else {
        this.showSaveAndContinue();
      }
    },

    isPayuChoosen: function () {
      return this.choosenPaymentMethodId() == this.payuPaymentMethodId();
    },

    choosenPaymentMethodId: function() {
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
    },
    toggleSaveAndContinueVisibility: function() {
      $('[data-hook="buttons"] button').toggle();
    }
  }

  $(document).ready(function() {
    SpreePayuIntegration.updateSaveAndContinueVisibility();

    $('div[data-hook="checkout_payment_step"] input[type="radio"]').change(SpreePayuIntegration.toggleSaveAndContinueVisibility);
  })
})(jQuery);
