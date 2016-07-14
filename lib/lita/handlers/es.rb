require 'elasticsearch'

module Lita
  module Handlers
    class Es < Handler

      feature :async_dispatch
      config :es_host, type: String, default: 'localhost'

      route(/^es\s+health/, :health, help: {
        "es health" => "Elasticsearch Cluster Health"
      })

      route(/^es\s+index.*summary/, :index_summary, help: {
        "es index summary" => "Elasticsearch Index Summary by Prefix"
      })

      route(/^es\s+index\s(?<input>.*)$/, :index_info, help: {
        "es index <prefix>" => "Elasticsearch Index Information"
      })

      @robot = Lita::Robot#chat_service

      def connect
        Elasticsearch::Client.new host: config.es_host
      end

      def health(response)
        begin
          @client = connect()
          health = @client.cluster.health

          color = "danger"
          color = "good" if health['status'] == "green"
          color = "warning" if health['status'] == "yellow"

          attachment = {
            title: 'Elasticsearch Cluster Health',
            text: health['status'],
            color: color,
            mrkdown_in: ["text"]
          }
          @robot.chat_service.send_attachment(response.message.source.room_object, [attachment])

          output = String.new
          health.each_pair do |key, value|
            output += sprintf("%-40s %-20s\n", key, value)
          end
          response.reply "```#{output.strip}```"

        rescue Exception => e
          response.reply "Error running command. ```#{e.message}```"
        end
      end

      def indices()
        index_info = {}
        @client = connect()
        indices_response = @client.cat.indices(bytes: "b")
        indices_response.split("\n").each do |line|
          # skip closed indices
          next if line.split().length != 9
          (index_health, index_status, index_name, pri_shard_count, rep_shard_multiplier, doc_count, doc_deleted_count, store_size, pri_store_size) = line.split()
          replica_shard_count = (pri_shard_count.to_i * rep_shard_multiplier.to_i).to_s
          # Ignore the 'trash' indices; they're not that interesting in most/all cases we care about.
          next if index_name =~ /-trash$/
          index_key = index_name.gsub(/-\d{4}(\.|-)\d{2}(\.|-)\d{2}/, '')
          index_info[index_key] = {} unless index_info.has_key?(index_key)
          index_info[index_key]['indices'] = [] unless index_info[index_key].has_key?('indices')
          index_info[index_key]['indices'] << {'index_name' => index_name, 'index_health' => index_health, 'store_size' => store_size, 'pri_store_size' => pri_store_size, 'pri_shard_count' => pri_shard_count, 'replica_shard_count' => replica_shard_count}
        end
        index_info
      end

      def index_summary(response)
        begin
          index_info = indices()
          index_info.each_pair do |key, value|
            index_info[key]['index_count'] = value['indices'].length()
            index_info[key]['store_size'] = value['indices'].inject(0) { |sum, hash| sum + hash['store_size'].to_i }
            index_info[key]['pri_store_size'] = value['indices'].inject(0) { |sum, hash| sum + hash['pri_store_size'].to_i }
            index_info[key]['pri_shard_count'] = value['indices'].inject(0) { |sum, hash| sum + hash['pri_shard_count'].to_i }
            index_info[key]['replica_shard_count'] = value['indices'].inject(0) { |sum, hash| sum + hash['replica_shard_count'].to_i }
          end

          output = sprintf("%-30s|%7s|%10s|%16s|%16s\n", "INDEX PREFIX ", " COUNT ", " SIZE(GB) ", " PRIMARY SHARDS ", " REPLICA SHARDS ")
          index_info.keys.sort.each do |index_prefix|
            output += sprintf("%-30s|%7s|%10s|%16s|%16s\n", "#{index_prefix} ", " #{index_info[index_prefix]['index_count']} ", " #{to_gb(index_info[index_prefix]['store_size'])} ", " #{index_info[index_prefix]['pri_shard_count']} ", " #{index_info[index_prefix]['replica_shard_count']} ")
          end
          response.reply "```#{output.strip}```"
        rescue Exception => e
          response.reply "Error running command. ```#{e.message}```"
        end
      end

      def index_info(response)
        begin
          index_prefix = response.match_data['input']
          index_info = indices

          if index_info.has_key?(index_prefix)
            output = sprintf("%-30s|%8s|%10s|%16s|%16s\n", "INDEX ", " HEALTH ", " SIZE(GB) ", " PRIMARY SHARDS ", " REPLICA SHARDS ")
            index_info[index_prefix]['indices'].each do |index|
              output += sprintf("%-30s|%8s|%10s|%16s|%16s\n", "#{index['index_name']} ", " #{index['index_health']} ", " #{to_gb(index['store_size'])} ", " #{index['pri_shard_count']} ", " #{index['replica_shard_count']} ")
            end
            response.reply "```#{output.strip}```"
          else
            response.reply "Index prefix '#{index_prefix}' not known. Try `es index summary` for a list of prefixes"
          end
        rescue Exception => e
          response.reply "Error running command. ```#{e.message}```"
        end
      end

      def to_gb(bytes)
        bytes.to_i/1024/1024/1024
      end

      Lita.register_handler(self)
    end
  end
end
