require 'elasticsearch'

module Lita
  module Handlers
    class Es < Handler

      feature :async_dispatch
      config :es_host, type: String, default: 'localhost'

      route(/^es\s+health/, :health, help: {
        "es health" => "Elasticsearch Cluster Health"
      })

      route(/^es\s+index-summary/, :index_summary, help: {
        "es index-summary" => "Elasticsearch Index Summary by Prefix"
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
          response.reply "```#{e.backtrace}```"
        end
      end

      def indices()
        index_info = {}
        @client = connect()
        indices_response = @client.cat.indices(bytes: "b", format: 'json')
        # {"health"=>"green", "status"=>"open", "index"=>"logstash-2017.07.26", "pri"=>"3", "rep"=>"1", 
        # "docs.count"=>"26283321", "docs.deleted"=>"0", "store.size"=>"46350009906", 
        # "pri.store.size"=>"23143853364"},

        indices_response.each do |line|

          index_key = line['index'].gsub(/-\d{4}(\.|-)\d{2}(\.|-)\d{2}/, '')
          index_info[index_key] = {} unless index_info.has_key?(index_key)
          index_info[index_key]['indices'] = [] unless index_info[index_key].has_key?('indices')
          index_info[index_key]['indices'] << line
        end
        index_info
      end

      def index_summary(response)
        begin
          index_info = indices()
          index_info.each_pair do |key, value|
            index_info[key]['index_count'] = value['indices'].length()
            index_info[key]['store_size'] = value['indices'].inject(0) { |sum, hash| sum + hash['store.size'].to_i }
            index_info[key]['doc_count'] = value['indices'].inject(0) { |sum, hash| sum + hash['docs.count'].to_i }
            index_info[key]['pri_store_size'] = value['indices'].inject(0) { |sum, hash| sum + hash['pri.store.size'].to_i }
            index_info[key]['pri_shard_count'] = value['indices'].inject(0) { |sum, hash| sum + hash['pri'].to_i }
          end

          output_lines = []
          index_info.keys.sort.each do |index_prefix|
            output_lines << sprintf("%-30s|%7s|%15s|%10s|%16s\n", "#{index_prefix} ", " #{index_info[index_prefix]['index_count']} ", " #{num_with_commas(index_info[index_prefix]['doc_count'])} ",  " #{to_gb(index_info[index_prefix]['store_size'])} ", " #{index_info[index_prefix]['pri_shard_count']} ")
            if output_lines.count == 40
              output = sprintf("%-30s|%7s|%15s|%10s|%16s\n", "INDEX PREFIX ", " COUNT ", " DOCUMENTS ", " SIZE(GB) ", " PRIMARY SHARDS ")
              output += output_lines.join
              response.reply "```#{output.strip}```"
              output_lines = []
            end
          end
          if output_lines.count > 0
            output = sprintf("%-30s|%7s|%15s|%10s|%16s\n", "INDEX PREFIX ", " COUNT ", " DOCUMENTS ", " SIZE(GB) ", " PRIMARY SHARDS ")
            output += output_lines.join
            response.reply "```#{output.strip}```"
          end
        rescue Exception => e
          response.reply "Error running command. ```#{e.message}```"
          response.reply "```#{e.backtrace}```"
        end
      end

      def index_info(response)
        begin
          index_prefix = response.match_data['input']
          index_info = indices

          if index_info.has_key?(index_prefix)
            output_lines = []
            index_info[index_prefix]['indices'].each do |index|
              output_lines << sprintf("%-30s|%8s|%15s|%10s|%16s\n", "#{index['index']} ", " #{index['health']} ", " #{num_with_commas(index['docs.count'])} ", " #{to_gb(index['store.size'])} ", " #{index['pri']} ")
              if output_lines.count == 40
                output = sprintf("%-30s|%8s|%15s|%10s|%16s\n", "INDEX ", " HEALTH ", " DOCUMENTS ", " SIZE(GB) ", " PRIMARY SHARDS ")
                output += output_lines.join
                response.reply "```#{output.strip}```"
                output_lines = []
              end
            end
            if output_lines.count > 0
              output = sprintf("%-30s|%8s|%15s|%10s|%16s\n", "INDEX ", " HEALTH ", " DOCUMENTS ", " SIZE(GB) ", " PRIMARY SHARDS ")
              output += output_lines.join
              response.reply "```#{output.strip}```"
            end
          else
            response.reply "Index prefix '#{index_prefix}' not known. Try `es index-summary` for a list of prefixes"
          end
        rescue Exception => e
          response.reply "Error running command. ```#{e.message}```"
          response.reply "```#{e.backtrace}```"
        end
      end

      def to_gb(bytes)
        bytes.to_i/1024/1024/1024
      end

      def num_with_commas(num)
        num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end

      Lita.register_handler(self)
    end
  end
end
