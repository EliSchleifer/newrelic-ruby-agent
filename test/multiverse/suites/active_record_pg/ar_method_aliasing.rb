# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

require 'rubygems'
require 'active_record'
require 'active_support/multibyte'
require_relative '../../lib/multiverse/color'
require_relative 'app/models/models'

class InstrumentActiveRecordMethods < Minitest::Test
  extend Multiverse::Color

  include MultiverseHelpers
  setup_and_teardown_agent

  def test_basic_creation
    a_user = User.new(:name => "Bob")

    assert_predicate a_user, :new_record?
    a_user.save!

    assert_predicate User, :connected?
    assert_predicate a_user, :persisted? if a_user.respond_to?(:persisted?)
  end

  def test_alias_collection_query_method
    a_user = User.new(:name => "Bob")
    a_user.save!

    a_user = User.first

    assert_predicate User, :connected?

    an_alias = Alias.new(:user_id => a_user.id, :aka => "the Blob")

    assert_predicate an_alias, :new_record?
    an_alias.save!
    assert_predicate an_alias, :persisted? if a_user.respond_to?(:persisted?)
    an_alias.destroy
    assert_predicate an_alias, :destroyed? if a_user.respond_to?(:destroyed?)
  end
end
