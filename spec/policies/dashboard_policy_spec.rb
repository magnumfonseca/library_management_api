# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DashboardPolicy do
  context 'for a librarian' do
    let(:user) { create(:user, :librarian) }
    let(:policy) { described_class.new(user, :dashboard) }

    it 'permits librarian action' do
      expect(policy.librarian?).to be true
    end

    it 'does not permit member action' do
      expect(policy.member?).to be false
    end
  end

  context 'for a member' do
    let(:user) { create(:user, :member) }
    let(:policy) { described_class.new(user, :dashboard) }

    it 'does not permit librarian action' do
      expect(policy.librarian?).to be false
    end

    it 'permits member action' do
      expect(policy.member?).to be true
    end
  end

  context 'for a guest (nil user)' do
    let(:user) { nil }
    let(:policy) { described_class.new(user, :dashboard) }

    it 'does not permit librarian action' do
      expect(policy.librarian?).to be_falsey
    end

    it 'does not permit member action' do
      expect(policy.member?).to be_falsey
    end
  end
end
