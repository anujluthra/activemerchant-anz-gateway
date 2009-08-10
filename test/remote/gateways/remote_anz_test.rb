require File.dirname(__FILE__) + '/../../test_helper'

class AnzTest < Test::Unit::TestCase
  def setup
    Base.gateway_mode = :test
    @gateway = AnzGateway.new(fixtures(:anz))

    @credit_card_success = credit_card('5123456789012346', 
                                          :month => 5,
                                          :year => 2013
                           )
    
    @credit_card_fail = credit_card('1234567812345678',
      :month => Time.now.month,
      :year => Time.now.year
    )
    
    @params = {
      :booking_number => '222222D',
      :unique_id => 'efad6659cea26be50fe36cbdec91f042',
    }
  end
  
  def test_invalid_amount
    assert response = @gateway.purchase(Money.new(0), @credit_card_success, @params)
    assert_failure response
    assert response.test?
  end
   
  def test_purchase_success_with_verification_value 
    assert response = @gateway.purchase(Money.new(100), @credit_card_success, @params)
    assert_success response
    assert response.test?
  end

#  def test_purchase_with_invalid_verification_value
#    @credit_card_success.verification_value = 'AAA'
#    assert response = @gateway.purchase(100, @credit_card_success, @params)
#    assert_nil response.authorization
#    assert_failure response
#    assert response.test?
#  end

  def test_invalid_expiration_date
    @credit_card_success.year = 2005 
    assert response = @gateway.purchase(100, @credit_card_success, @params)
    assert_failure response
    assert response.test?
  end
  
  def test_purchase_error
    assert response = @gateway.purchase(100, @credit_card_fail, @params)
    assert_equal false, response.success?
    assert response.test?
  end
end
