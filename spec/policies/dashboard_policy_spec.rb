# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardPolicy do
  context 'for a librarian' do
    let(:user) { create(:user, :librarian) }
    let(:policy) { described_class.new(user, :dashboard) }

    it 'permits show action' do
      expect(policy.show?).to be true
    end
  end

  context 'for a member' do
    let(:user) { create(:user, :member) }
    let(:policy) { described_class.new(user, :dashboard) }

    it 'permits show action' do
      expect(policy.show?).to be true
    end
  end

  context 'for a guest (nil user)' do
    let(:user) { nil }
    let(:policy) { described_class.new(user, :dashboard) }

    it 'denies show action' do
      expect(policy.show?).to be_falsey
    end
  end
end
