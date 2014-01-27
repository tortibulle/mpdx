if defined?(PhusionPassenger)
  Mpdx::Application.configure do
    config.middleware.use PhusionPassenger::Rack::OutOfBandGc, 5

    PhusionPassenger.on_event(:oob_work) do
      GC.start
    end
  end

end