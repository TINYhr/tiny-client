require 'test_helper'

describe TinyClient::PaginationSupport do
  MyResource = Class.new(TinyClient::Resource)
  let('batch') { ->(range) { range.each_with_object([]) { |i, a| a << { id: i } } } }

  it { MyResource.must_respond_to :get_all }
  it { MyResource.must_respond_to :index_all }
  it { MyResource.must_respond_to :get_in_batches }
  it { MyResource.must_respond_to :index_in_batches }

  describe 'ClassMethods#get_all' do
    before do
      MyResource.fields :id
      MyResource.path 'my'
      MyResource.conf OpenStruct.new(limit: 10, url: 'http://acme.org', headers: {})
    end

    it { MyResource.get_all.must_be_instance_of Enumerator }

    it 'make one query when the first batch contains less than limit' do
      stub_request(:get, 'http://acme.org/my.json').with(query: { limit: 10, offset: 0 })
                                                   .to_return(body: batch.call(1..9).to_json)
      enum = MyResource.get_all
      enum.first.must_be_instance_of MyResource
      enum.first.id.must_equal 1
      enum.count.must_equal 9
    end

    it 'make two query when the first batch contains exactly limit' do
      stub_request(:get, 'http://acme.org/my.json').with(query: { limit: 10, offset: 0 })
                                                   .to_return(body: batch.call(1..10).to_json)
      stub_request(:get, 'http://acme.org/my.json').with(query: { limit: 10, offset: 10 })
                                                   .to_return(body: [].to_json)
      MyResource.get_all.count.must_equal 10
    end

    it 'make three query when there is 28 elements and the limit is 10' do
      stub_request(:get, 'http://acme.org/my.json').with(query: { limit: 10, offset: 0 })
                                                   .to_return(body: batch.call(1..10).to_json)
      stub_request(:get, 'http://acme.org/my.json').with(query: { limit: 10, offset: 10 })
                                                   .to_return(body: batch.call(11..20).to_json)
      stub_request(:get, 'http://acme.org/my.json').with(query: { limit: 10, offset: 20 })
                                                   .to_return(body: batch.call(21..28).to_json)
      enum = MyResource.get_all.each
      enum.each_with_index do |res, i|
        res.must_be_instance_of MyResource
        res.id.must_equal(i + 1)
      end
      enum.count.must_equal 28
    end
  end
end