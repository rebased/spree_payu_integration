(function($) {
  var SpreePayuIntegration = {
    updatePayuSelectedClass: function(e) {
      $('#checkout_form_payment').toggleClass('payu_selected', this.isPayuChoosen(e));
    },

    isPayuChoosen: function(e) {
      return this.choosenPaymentMethodId(e) === this.payuPaymentMethodId();
    },

    choosenPaymentMethodId: function(e) {
      if (e) {
        return $(e.target).val();
      }

      var name = 'order[payments_attributes][][payment_method_id]';
      return $('[name="' + name + '"]').val();
    },

    payuPaymentMethodId: function() {
      return $('#payu_button').data('payment-method-id');
    }
  };

  $(document).ready(function() {
    SpreePayuIntegration.updatePayuSelectedClass();

    $('div[data-hook="checkout_payment_step"] input[type="radio"]').change(function(e) {
      SpreePayuIntegration.updatePayuSelectedClass(e);
    });
  });
})(jQuery);
