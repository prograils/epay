require 'spec_helper'

module Epay
  describe Transaction do
    let(:transaction) do
      VCR.use_cassette('existing_transaction') do
        Transaction.find(EXISTING_TRANSACTION_ID)
      end
    end
    
    describe "attributes" do
      it "has description" do
        transaction.description.should == "Description of transaction"
      end
      
      it "has amount" do
        transaction.amount.should == 79.0
      end
      
      it "has card" do
        Card.should_receive(:new).with(:number => '333333XXXXXX3000', :exp_year => 12, :exp_month => 10, :kind => :visa)
        transaction.card
      end
      
      it "has group" do
        transaction.group.should == 'Group'
      end
      
      it "has cardholder" do
        transaction.cardholder.should == 'John Doe'
      end
      
      it "has acquirer" do
        transaction.acquirer.should == 'EUROLINE'
      end
      
      it "has currency" do
        transaction.currency.should == :DKK
      end
      
      it "has order no" do
        transaction.order_no.should == 'MY-ORDER-ID'
      end
      
      it "has created_at" do
        transaction.created_at.should == Time.new(2012, 2, 10, 11, 30, 0)
      end
      
      it "has error" do
        transaction.data.stub(:[]).with('error') { 404 }
        transaction.error.should == 404
      end
    end
    
    describe "#test?" do
      it "is true when mode is EPAY or TEST" do
        transaction.data.stub(:[]).with('mode') { 'MODE_EPAY' }
        transaction.test?.should be_true
        
        transaction.data.stub(:[]).with('mode') { 'MODE_TEST' }
        transaction.test?.should be_true
      end
      
      it "is false when in production" do
        transaction.data.stub(:[]).with('mode') { 'MODE_PRODUCTION' }
        transaction.test?.should be_false
      end
    end
    
    describe "#production?" do
      it "is opposite of test?" do
        transaction.stub(:test?) { false }
        transaction.production?.should be_true
        
        transaction.stub(:test?) { true }
        transaction.production?.should be_false
      end
    end
    
    describe "#captured?" do
      it "is true when captured_at is set" do
        transaction.stub(:captured_at) { Time.now }
        transaction.captured?.should be_true
      end
      
      it "is false when captured_at isn't set" do
        transaction.stub(:captured_at) { nil }
        transaction.captured?.should be_false
      end
    end
    
    describe "#failed?" do
      it "is true when 'failed' is set" do
        transaction.should_not be_failed
        transaction.data.stub(:[]).with('failed') { true }
        transaction.should be_failed
      end
    end
    
    describe "#success?" do
      it "is true unless failed" do
        transaction.stub(:failed?) { false }
        transaction.success?.should be_true
        
        transaction.stub(:failed?) { true }
        transaction.success?.should be_false
      end
    end
    
    describe "#capture" do
      it "calls capture action with transaction id and amount in minor" do
        transaction.stub(:amount) { 10 }
        Api.should_receive(:request).with(PAYMENT_SOAP_URL, 'capture', :transactionid => transaction.id, :amount => 1000).and_return(mock('response', :success? => false))
        transaction.capture
      end
      
      context "when request is success" do
        it "reloads and returns true" do
          transaction
          Api.stub(:request).with(PAYMENT_SOAP_URL, 'capture', anything).and_return(mock('response', :success? => true))
          transaction.should_receive(:reload)
          transaction.capture.should be_true
        end
      end
      
      context "when request fails" do
        it "returns false" do
          transaction
          Epay::Api.stub(:request) { mock('response', :success? => false) }
          transaction.capture.should be_false
        end
      end
    end
    
    describe ".find" do
      it "returns a transaction" do
        VCR.use_cassette('existing_transaction') do
          Transaction.find(EXISTING_TRANSACTION_ID).should be_a Transaction
        end
      end
    
      it "reloads transaction data" do
        Transaction.any_instance.should_receive(:reload)
        Transaction.find(EXISTING_TRANSACTION_ID)
      end
      
      context "when transaction doesn't exist" do
        it "raises exception" do
          VCR.use_cassette('non_existing_transaction') do
            lambda { Transaction.find(NON_EXISTING_TRANSACTION_ID) }.should raise_error(TransactionNotFound)
          end
        end
      end
    end
  end
end