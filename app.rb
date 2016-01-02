require 'sinatra'
require 'sinatra/activerecord'
require './environments'

require 'net/http'
require 'uri'

class Pathfinder
  attr_reader :data

  def initialize data:
    @data = data
  end

  def search goal:, method: :bfs
    queue = []
    # Allow all starting positions
    data.keys.each do |metric|
      next if data[metric].zero?
      data[metric] = Integer(data[metric]) if data[metric] == Integer(data[metric])
      queue << {value: data[metric], operation_in: "#{data[metric]} #{metric}", metric: metric, parent: nil, distance: 0}
    end

    while queue.any?
      current = case method
        when :bfs
          queue.shift
        when :dfs
          queue.pop
      end

      if current[:value] == goal
        path = [current]
        while !current[:parent].nil?
          path << current[:parent]
          current = current[:parent]
        end
        return path.reverse
      end

      neighbors = adjacent_neighbors(from: current).select { |neighbor| valid_transition?(current, neighbor, queue, goal) }
      queue.concat neighbors
    end

    return []
  end

  def valid_transition? current, neighbor, queue, goal
    !invalid_transition? current, neighbor, queue, goal
  end

  def invalid_transition? current = {value: 0, metric: nil}, neighbor, queue, goal
    [
      queue.any? { |node| neighbor[:value].to_f == node[:value].to_f },
      queue.any? { |node| neighbor[:metric] == node[:metric] },
      neighbor[:value] == current[:value],
      neighbor[:metric] == current[:metric],
      neighbor[:value].zero?,
      neighbor[:value] < 0,
      neighbor[:value] > goal * 15,
      neighbor[:distance] > 10
    ].any?
  end

  private

  def valid_operations lhs:, rhs:, suffix:
    [
      {
        operation: Proc.new { lhs * rhs },
        description: "#{lhs} * #{rhs}#{suffix.end_with?('percentage') ? '%' : ''} #{suffix}"
      },
      {
        condition: Proc.new { !rhs.zero? },
        operation: Proc.new { lhs.to_f / rhs.to_f },
        description: "#{lhs} / #{rhs}#{suffix.end_with?('percentage') ? '%' : ''} #{suffix}"
      },
      {
        condition: Proc.new { !rhs.zero? },
        operation: Proc.new { lhs.to_f % rhs.to_f },
        description: "#{lhs} mod #{rhs}#{suffix.end_with?('percentage') ? '%' : ''} #{suffix}"
      },
      {
        operation: Proc.new { lhs + rhs },
        description: "#{lhs} + #{rhs}#{suffix.end_with?('percentage') ? '%' : ''} #{suffix}"
      },
      {
        operation: Proc.new { lhs - rhs },
        description: "#{lhs} - #{rhs}#{suffix.end_with?('percentage') ? '%' : ''} #{suffix}"
      },
      {
        condition: Proc.new { Integer(lhs) == lhs && lhs % 10 != 0 },
        operation: Proc.new { lhs.to_s.reverse.to_i },
        description: "#{lhs} reversed",
        added_distance: 1
      },
      {
        condition: Proc.new { lhs % 1 != 0 && (lhs + 0.5).to_i == lhs.to_i },
        operation: Proc.new { lhs.to_i },
        description: "#{lhs} rounded down",
        added_distance: 1
      },
      {
        condition: Proc.new { lhs % 1 != 0 && (lhs + 0.5).to_i != lhs.to_i },
        operation: Proc.new { (lhs + 0.5).to_i },
        description: "#{lhs} rounded up",
        added_distance: 1
      }
    ]
  end

  def adjacent_neighbors from:
    # from: {value: 5, operation_in: '5 words', parent: {value: 10, ...}, distance: 3}

    neighbors = []
    data.each do |metric, metric_value|
      next unless metric_value.is_a?(Integer) || metric_value.is_a?(Float)

      valid_operations(lhs: from[:value], rhs: metric_value, suffix: metric).each do |op|
        next if op.key?(:condition) && !op[:condition].call

        result = op[:operation].call
        result = Integer(result) if result == Integer(result)
        neighbors << {
          value:        result,
          operation_in: "#{op[:description]} = #{result}",
          metric:       metric,
          parent:       from,
          distance:     from[:distance] + 1 + (op.key?(:added_distance) ? op[:added_distance] : 0)
        }
      end
    end

    neighbors
  end
end

class Dactyl
  def self.analyze message
    #todo mass params for just the metrics we want
    uri = URI.parse("http://www.dactyl.in/api/v1/dactyl?text=#{message}")
    http = Net::HTTP.new(uri.host, uri.port)

    request = Net::HTTP::Get.new(uri.request_uri)
    response = http.request(request)

    begin
      data = JSON.parse(response.body)["metrics"]   
      data = sanitize data
      data
    rescue
      { # some default data
        word_count: message.split(' ').length,
        character_count: message.chars.length,
        spaces: message.count(' ')
      }
    end
  end

  def self.sanitize hash
    hash
      .select!     { |key, value| value.is_a?(Integer) || value.is_a?(Float) }
      .merge(hash) { |key, value| key.end_with?('_percentage') ? value * 100 : value }
  end
end

get '/' do
    erb :"apidocs"
end

get '/proof' do
    content_type :json
    question = params[:question]

    data = Dactyl.analyze(question)
    pf = Pathfinder.new data: data
    steps = pf.search goal: 3, method: :dfs

    if steps.any?
        steps.map! { |step| "#{step[:operation_in].gsub('_', ' ')}"}
        steps << "HL3 confirmed."
    end

    steps.to_json
end








