SpreePayuIntegration - maintained fork
======================================

[![Circle CI](https://circleci.com/gh/rebased/spree_payu_integration.svg?style=svg)](https://circleci.com/gh/rebased/spree_payu_integration)


Spree integration with OpenPayU payment service.

This is a maintained fork of [netguru/spree_payu_integration](https://github.com/netguru/spree_payu_integration).

Changes:

* Updated to work with Spree 3
* Requests to PayU are done in separate controller, not in before filter

Installation
------------

Add spree_payu_integration to your Gemfile:

```ruby
gem 'spree_payu_integration', github: 'rebased/spree_payu_integration'
```

Bundle your dependencies and run the installation generator:

```shell
bundle
bundle exec rails g spree_payu_integration:install
```

Configuration
-------------

Don't forget to insert seller account details into `config/initializers/openpayu.rb`

Pay with Payu button
--------------------

`spree_payu_integration` adds a `payu_selected` css class to `form#checkout_form_payment`
when PayU payment is selected, and removes this class if some other payment
is choosen. To use this functionality, just add `//= require spree/frontend/spree_payu_integration` to your `application.js`.

This is so developer can conditionally hide "Save and Continue" button with css,
so "Pay with PayU" button can be positioned in exact same spot than "Save and Continue".

**REMEMBER: This is your job to write CSSes that hides "Save and Continue" button.**

Testing
-------

Be sure to bundle your dependencies and then create a dummy test app for the specs to run against.

```shell
bundle
bundle exec rake test_app
bundle exec rspec spec
```

When testing your applications integration with this extension you may use it's factories.
Simply add this require statement to your spec_helper:

```ruby
require 'spree_payu_integration/factories'
```

Original authors: [netguru](https://netguru.co), released under the New BSD License.

This fork maintained by [rebased](https://rebased.pl).
