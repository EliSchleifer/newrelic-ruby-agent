# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/newrelic-ruby-agent/blob/main/LICENSE for complete details.
# frozen_string_literal: true

module NewRelic
  module Agent
    class Agent
      module Harvest
        # Harvests data from the given container, sends it to the named endpoint
        # on the service, and automatically merges back in upon a recoverable
        # failure.
        #
        # The given container should respond to:
        #
        #  #harvest!
        #    returns a payload that contains enumerable collection of data items and
        #    optional metadata to be sent to the collector.
        #
        #  #reset!
        #    drop any stored data and reset to a clean state.
        #
        #  #merge!(payload)
        #    merge the given payload back into the internal buffer of the
        #    container, so that it may be harvested again later.
        #
        def harvest_and_send_from_container(container, endpoint)
          payload = harvest_from_container(container, endpoint)
          sample_count = harvest_size(container, payload)
          if sample_count > 0
            NewRelic::Agent.logger.debug("Sending #{sample_count} items to #{endpoint}")
            send_data_to_endpoint(endpoint, payload, container)
          end
        end

        def harvest_size(container, items)
          if container.respond_to?(:has_metadata?) && container.has_metadata? && !items.empty?
            items.last.size
          else
            items.size
          end
        end

        def harvest_from_container(container, endpoint)
          items = []
          begin
            items = container.harvest!
          rescue => e
            NewRelic::Agent.logger.error("Failed to harvest #{endpoint} data, resetting. Error: ", e)
            container.reset!
          end
          items
        end

        def harvest_and_send_timeslice_data
          TransactionTimeAggregator.harvest!
          harvest_and_send_from_container(@stats_engine, :metric_data)
        end

        def harvest_and_send_slowest_sql
          harvest_and_send_from_container(@sql_sampler, :sql_trace_data)
        end

        # This handles getting the transaction traces and then sending
        # them across the wire.  This includes gathering SQL
        # explanations, stripping out stack traces, and normalizing
        # SQL.  note that we explain only the sql statements whose
        # nodes' execution times exceed our threshold (to avoid
        # unnecessary overhead of running explains on fast queries.)
        def harvest_and_send_transaction_traces
          harvest_and_send_from_container(@transaction_sampler, :transaction_sample_data)
        end

        def harvest_and_send_for_agent_commands
          harvest_and_send_from_container(@agent_command_router, :profile_data)
        end

        def harvest_and_send_errors
          harvest_and_send_from_container(@error_collector.error_trace_aggregator, :error_data)
        end

        def harvest_and_send_analytic_event_data
          harvest_and_send_from_container(transaction_event_aggregator, :analytic_event_data)
          harvest_and_send_from_container(synthetics_event_aggregator, :analytic_event_data)
        end

        def harvest_and_send_custom_event_data
          harvest_and_send_from_container(@custom_event_aggregator, :custom_event_data)
        end

        def harvest_and_send_error_event_data
          harvest_and_send_from_container(@error_collector.error_event_aggregator, :error_event_data)
        end

        def harvest_and_send_span_event_data
          harvest_and_send_from_container(span_event_aggregator, :span_event_data)
        end

        def harvest_and_send_log_event_data
          harvest_and_send_from_container(@log_event_aggregator, :log_event_data)
        end

        def harvest_and_send_data_types
          harvest_and_send_errors
          harvest_and_send_error_event_data
          harvest_and_send_transaction_traces
          harvest_and_send_slowest_sql
          harvest_and_send_timeslice_data
          harvest_and_send_span_event_data
          harvest_and_send_log_event_data
        end
      end

      include Harvest
    end
  end
end
