module RailsEventStore
  module Browser
    class StreamsController < ApplicationController
      def index
        streams = event_store.get_all_streams
        render json: { data: streams.map { |s| serialize_stream(s) } }, content_type: 'application/vnd.api+json'
      end

      def show
        links  = {}
        events = case direction
        when :forward
          event_store
            .read_events_forward(stream_name, start: position, count: count)
            .reverse
        when :backward
          event_store
            .read_events_backward(stream_name, start: position, count: count)
        end

        if prev_event?(events)
          links[:prev]  = prev_page_link(events.first.event_id)
          links[:first] = first_page_link
        end

        if next_event?(events)
          links[:next] = next_page_link(events.last.event_id)
          links[:last] = last_page_link
        end

        render json: {
          data: events.map { |e| serialize_event(e) },
          links: links
        }, content_type: 'application/vnd.api+json'
      end

      private

      def next_event?(events)
        return if events.empty?
        event_store.read_events_backward(stream_name, start: events.last.event_id).present?
      end

      def prev_event?(events)
        return if events.empty?
        event_store.read_events_forward(stream_name, start: events.first.event_id).present?
      end

      def prev_page_link(event_id)
        stream_url(position: event_id, direction: :forward, count: count)
      end

      def next_page_link(event_id)
        stream_url(position: event_id,  direction: :backward, count: count)
      end

      def first_page_link
        stream_url(position: :head, direction: :backward, count: count)
      end

      def last_page_link
        stream_url(position: :head, direction: :forward, count: count)
      end

      def count
        Integer(params.fetch(:count, PAGE_SIZE))
      end

      def direction
        case params[:direction]
        when 'forward'
          :forward
        else
          :backward
        end
      end

      def position
        case params[:position]
        when nil, 'head'
          :head
        else
          params.fetch(:position)
        end
      end

      def stream_name
        params.fetch(:id)
      end

      def serialize_stream(stream)
        {
          id: stream.name,
          type: "streams"
        }
      end

      def serialize_event(event)
        {
          id: event.event_id,
          type: "events",
          attributes: {
            event_type: event.class.to_s,
            data: event.data,
            metadata: event.metadata
          }
        }
      end
    end
  end
end