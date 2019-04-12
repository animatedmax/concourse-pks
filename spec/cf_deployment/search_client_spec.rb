require_relative '../../cf_deployment/search_client'

module CfDeployment
  describe SearchClient do
    let(:indexer) { double(:indexer, parse_pages: nil) }
    let(:getter) { double(:getter, request: nil) }
    let(:client) { SearchClient.new(indexer, getter, { guid: 'GUID-BUID-LUID-DUID', name: 'app-name-green' }, mock_printer) }

    let(:mock_printer) { double(:printer, puts: nil, print: nil) }

    let(:mock_indices) { double(:indices, create: nil, delete: nil, update_aliases: nil) }
    let(:mock_elastic_search) { double(:elastic_search, indices: mock_indices, index: nil) }

    before do
      allow(Elasticsearch::Client).to receive(:new) { mock_elastic_search }
    end

    context 'with elastic search configured via searchly' do
      let(:env_with_searchly) do
        {
          'system_env_json' => {
            'VCAP_SERVICES' => {
              'searchly' => [
                {
                  'credentials' => {
                    'sslUri' => 'http://searchly.example.com'
                  }
                }
              ]
            }
          }
        }
      end

      before do
        allow(getter).to receive(:request) { env_with_searchly }
      end

      it 'uses search' do
        allow(mock_indices).to receive(:get_alias) { {} }
        expect(client).to be_use_search
        expect(client.search_service).to eq('searchly')
      end

      it 'converts emerald index to sapphire' do
        allow(mock_indices).to receive(:get_alias).with(name: 'searching') do
          {
            'foo' => 'bunch of stuff',
            'app-name-version-sapphire' => 'not me',
            'app-name-emerald' => 'it is me'
          }
        end

        expect(client.updating_index).to eq('app-name-sapphire')
        expect(client.current_index).to eq('app-name-emerald')
      end

      it 'converts sapphire index to emerald' do
        allow(mock_indices).to receive(:get_alias).with(name: 'searching') do
          {
            'foo' => 'bunch of stuff',
            'app-name-version-sapphire' => 'not me',
            'app-name-sapphire' => 'it is me'
          }
        end

        expect(client.updating_index).to eq('app-name-emerald')
        expect(client.current_index).to eq('app-name-sapphire')
      end

      it 'creates a new emerald if no index exists' do
        allow(mock_indices).to receive(:get_alias).with(name: 'searching') do
          {
            'foo' => 'bunch of stuff',
            'app-name-version-sapphire' => 'not me'
          }
        end

        expect(client.updating_index).to eq('app-name-sapphire')
        expect(client.current_index).to eq('app-name-emerald')
      end

      it 'indexes the pages the indexer finds' do
        allow(mock_indices).to receive(:get_alias) do
          { 'app-name-emerald' => 'pick me' }
        end
        allow(indexer).to receive(:parse_pages).and_yield('hi').and_yield('bye').and_yield('stuff')

        client.index_site

        expect(getter).to have_received(:request).with('/v2/apps/GUID-BUID-LUID-DUID/env')
        expect(Elasticsearch::Client).to have_received(:new).with(url: 'http://searchly.example.com')

        expect(mock_indices).to have_received(:get_alias)
        expect(mock_indices).to have_received(:create).with(hash_including(index: 'app-name-sapphire'))

        expect(mock_elastic_search).to have_received(:index).with(index: 'app-name-sapphire', type: 'page', body: 'hi')
        expect(mock_elastic_search).to have_received(:index).with(index: 'app-name-sapphire', type: 'page', body: 'bye')
        expect(mock_elastic_search).to have_received(:index).with(index: 'app-name-sapphire', type: 'page', body: 'stuff')
      end

      it 'swaps the old index for the new one' do
        allow(mock_indices).to receive(:get_alias) do
          { 'app-name-emerald' => 'pick me' }
        end
        allow(mock_indices).to receive(:update_aliases)
        allow(mock_indices).to receive(:delete)

        client.swap_indices

        expect(mock_indices).to have_received(:update_aliases).with(body: {
          actions: [
            { add: { index: 'app-name-sapphire', alias: 'searching' } },
            { remove: { index: 'app-name-emerald', alias: 'searching' } }
          ]
        })
        expect(mock_indices).to have_received(:delete).with(index: 'app-name-emerald', timeout: anything)
      end

      it 'does not remove an index that does not exist' do
        allow(mock_indices).to(receive(:get_alias).with(name: 'searching')) { {} }
        allow(mock_indices).to receive(:update_aliases)
        allow(mock_indices).to receive(:delete)

        client.swap_indices

        expect(mock_indices).to have_received(:update_aliases).with(body: {
          actions: [
            { add: { index: 'app-name-sapphire', alias: 'searching' } }
          ]
        })
        expect(mock_indices).not_to have_received(:delete)
      end

      it 'deletes an index' do
        allow(mock_indices).to(receive(:get_alias).with(name: 'searching')) { {} }

        client.delete_index('foo-bar-baz')

        expect(mock_indices).to have_received(:delete).with(index: 'foo-bar-baz', timeout: anything)
      end
    end

    context 'with elastic search configured via elastic.co' do
      let(:env_with_elasticco) do
        {
          'system_env_json' => {
            'VCAP_SERVICES' => {
              'user-provided' => [
                {
                  'name' => 'elastic.co',
                  'credentials' => {
                    'sslUri' => 'http://elastic.example.com'
                  }
                }
              ]
            }
          }
        }
      end

      before do
        allow(getter).to receive(:request) { env_with_elasticco }
      end

      it 'talks to elastic co' do
        allow(mock_indices).to receive(:get_alias) do
          { 'app-name-emerald' => 'pick me' }
        end
        client

        expect(client).to be_use_search
        expect(client.search_service).to eq('elastic.co')
        expect(Elasticsearch::Client).to have_received(:new).with(url: 'http://elastic.example.com')
      end
    end

    context 'with elastic search configured via elastic.co and searchly' do
      let(:env_with_both) do
        {
          'system_env_json' => {
            'VCAP_SERVICES' => {
              'searchly' => [
                {
                  'credentials' => {
                    'sslUri' => 'http://searchly.example.com'
                  }
                }
              ],
              'user-provided' => [
                {
                  'name' => 'elastic.co',
                  'credentials' => {
                    'sslUri' => 'http://elastic.example.com'
                  }
                }
              ]
            }
          }
        }
      end

      before do
        allow(getter).to receive(:request) { env_with_both }
      end

      it 'talks to elastic co' do
        allow(mock_indices).to receive(:get_alias) do
          { 'app-name-emerald' => 'pick me' }
        end
        client

        expect(client).to be_use_search
        expect(client.search_service).to eq('elastic.co')
        expect(Elasticsearch::Client).to have_received(:new).with(url: 'http://elastic.example.com')
      end
    end

    context 'with no elastic search configured' do
      let(:env_without_searchly) do
        {
          'system_env_json' => {
            'VCAP_SERVICES' => {}
          }
        }
      end

      before do
        allow(getter).to receive(:request) { env_without_searchly }
      end

      it 'does not use search' do
        expect(client).not_to be_use_search
        expect(client.search_service).to be_nil
      end

      it 'does not detect indices' do
        client

        expect(getter).to have_received(:request).with('/v2/apps/GUID-BUID-LUID-DUID/env')
        expect(Elasticsearch::Client).not_to have_received(:new)

        expect(client.updating_index).to be_nil
        expect(client.current_index).to be_nil
      end

      it 'does not index' do
        client.index_site

        expect(indexer).not_to have_received(:parse_pages)
        expect(mock_elastic_search).not_to have_received(:index)
      end

      it 'does not swap indices' do
        client.swap_indices

        expect(mock_indices).not_to have_received(:update_aliases)
        expect(mock_indices).not_to have_received(:delete)
      end

      it 'does not delete indices' do
        client.delete_index('foo-bar-baz')

        expect(mock_indices).not_to have_received(:delete)
      end
    end
  end
end
