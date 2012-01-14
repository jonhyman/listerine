require 'sinatra/base'
require 'listerine'

module Listerine
  class Server < Sinatra::Base
    dir = File.dirname(File.expand_path(__FILE__))

    set :views,  "#{dir}/server/views"

    if respond_to?(:public_folder)
      set(:public_folder, "#{dir}/server/public")
    else
      set(:public, "#{dir}/server/public")
    end

    set :static, true
    set :port, 4568

    helpers do
      def distance_of_time_in_words(from_time, to_time = 0, include_seconds = false)
        from_time = from_time.to_time if from_time.respond_to?(:to_time)
        to_time = to_time.to_time if to_time.respond_to?(:to_time)
        distance_in_minutes = (((to_time - from_time).abs)/60).round
        distance_in_seconds = ((to_time - from_time).abs).round

        case distance_in_minutes
          when 0..1
            return (distance_in_minutes == 0) ? 'less than a minute' : '1 minute' unless include_seconds
            case distance_in_seconds
              when 0..4   then 'less than 5 seconds'
              when 5..9   then 'less than 10 seconds'
              when 10..19 then 'less than 20 seconds'
              when 20..39 then 'half a minute'
              when 40..59 then 'less than a minute'
              else             '1 minute'
            end

          when 2..44           then "#{distance_in_minutes} minutes"
          when 45..89          then 'about 1 hour'
          when 90..1439        then "about #{(distance_in_minutes.to_f / 60.0).round} hours"
          when 1440..2879      then '1 day'
          when 2880..43199     then "#{(distance_in_minutes / 1440).round} days"
          when 43200..86399    then 'about 1 month'
          when 86400..525599   then "#{(distance_in_minutes / 43200).round} months"
          when 525600..1051199 then 'about 1 year'
          else                      "over #{(distance_in_minutes / 525600).round} years"
        end
      end

      def name_to_id(name)
        n = name.dup
        n.gsub!(' ', '-')
        n.gsub!(/[^A-Za-z0-9\-]/, '')
        n.downcase
      end
    end

    get '/' do
      @persistence = Listerine::Options.instance.persistence_layer
      @monitors = @persistence.monitors
      @since = Time.now
      erb :index
    end

    post '/monitors/:id/enable' do
      @persistence = Listerine::Options.instance.persistence_layer
      content_type :json

      enable = params[:enable] == "true"
      id = params[:id]
      info = id.split('_')
      name = params[:name]
      environment = info[1]

      if enable
        @persistence.enable(name, environment)
      else
        @persistence.disable(name, environment)
      end

      {}
    end

    run! if app_file == $0
  end
end
