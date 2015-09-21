require 'spec_helper'

describe 'nova::extensions' do

  context 'with default parameters' do
    it 'installes extensions' do
      is_expected.to contain_package('fping').with_ensure('present')
    end
  end

end
